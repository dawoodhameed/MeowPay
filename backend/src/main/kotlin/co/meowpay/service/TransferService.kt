package co.meowpay.service

import co.meowpay.repository.TransferRepository
import org.springframework.dao.DataIntegrityViolationException
import org.springframework.stereotype.Service

/**
 * Orchestrates a transfer and owns the idempotent-replay path.
 *
 * **This class is deliberately not `@Transactional`.** Its job is to react to a
 * transaction that has already failed, which is only possible from outside that
 * transaction. Postgres aborts an entire transaction on any statement error, so once
 * the duplicate-key insert in [TransferExecutor] raises `23505`, nothing further can
 * be read on that connection -- every subsequent statement fails with
 * `25P02 current_transaction_is_aborted`. The rollback has to complete first, and only
 * then can the winning row be read, in a new transaction.
 *
 * That is why the obvious implementation -- catch the violation inside the
 * transactional method and select the existing transfer there -- cannot work, and why
 * the recovery lives here instead.
 */
@Service
class TransferService(
    private val executor: TransferExecutor,
    private val transferRepository: TransferRepository,
) {
    fun transfer(command: TransferCommand): TransferResult {
        // Checked before any database work: a self-transfer would otherwise lock the
        // same row twice and the intent is invalid regardless of state.
        if (command.senderWalletId == command.recipientWalletId) {
            throw SelfTransferException()
        }
        if (command.amount <= 0) {
            throw AmountNotPositiveException(command.amount)
        }

        return try {
            TransferResult(executor.execute(command), replayed = false)
        } catch (e: DataIntegrityViolationException) {
            // The unique index on idempotency_key rejected the insert, so this key
            // belongs to a transfer that already committed. Nothing was written by this
            // attempt -- the executor's transaction rolled back whole.
            //
            // Reaching this branch is the *normal* outcome for a retry, not an error
            // path. It is also how concurrent duplicates resolve: the second request
            // blocks on the uncommitted index entry until the first commits, then
            // lands here. No application-level check could serialise those two
            // requests, because both would pass a pre-flight SELECT.
            replay(command, e)
        }
    }

    private fun replay(
        command: TransferCommand,
        cause: DataIntegrityViolationException,
    ): TransferResult {
        // A fresh transaction: this call runs outside the aborted one, so the read
        // succeeds where it would have failed inside it.
        val existing =
            transferRepository.findByIdempotencyKey(command.idempotencyKey)
                // The violation came from some other constraint -- a foreign key, say --
                // so it is not an idempotency replay at all. Rethrowing keeps a genuine
                // data error from being reported as a successful duplicate.
                ?: throw cause

        // Same key, different money. Returning the earlier transfer here would tell the
        // caller their transfer succeeded when it never happened.
        if (existing.requestFingerprint != command.fingerprint()) {
            throw IdempotencyKeyReuseException(command.idempotencyKey)
        }

        return TransferResult(existing, replayed = true)
    }
}

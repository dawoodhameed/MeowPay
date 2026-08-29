package co.meowpay.service

import co.meowpay.domain.Transfer
import co.meowpay.domain.TransferStatus
import co.meowpay.repository.TransferRepository
import co.meowpay.repository.WalletRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.UUID

/**
 * The transactional half of a transfer: lock, verify, move, record -- all or nothing.
 *
 * This is a separate bean from [TransferService] on purpose, and the separation is
 * load-bearing rather than stylistic. Spring applies `@Transactional` through a proxy,
 * so a call from one method to another *on the same instance* bypasses the interceptor
 * entirely. If [TransferService] held both halves, its recovery path would run inside
 * this method's already-aborted transaction instead of a fresh one, and every read
 * there would fail with `25P02 current_transaction_is_aborted`.
 */
@Service
class TransferExecutor(
    private val walletRepository: WalletRepository,
    private val transferRepository: TransferRepository,
) {
    /**
     * Runs the whole movement in one transaction. Any failure -- including the unique
     * violation on a duplicate idempotency key -- rolls back both balance writes and
     * the transfer row together, so the ledger is never left half-applied.
     */
    @Transactional
    fun execute(command: TransferCommand): Transfer {
        // Ordering the locks is what prevents deadlock, and it has to happen before
        // either row is touched. Two transfers in opposite directions between the same
        // pair (A->B and B->A) would otherwise each hold the row the other needs.
        // Sorting the ids gives every transaction the same acquisition order, which
        // makes a wait-for cycle impossible to construct.
        //
        // The comparator only has to be total and applied identically everywhere -- it
        // does not need to agree with Postgres's own uuid collation, which orders bytes
        // unsigned while Java compares two signed longs. Consistency within this
        // application is the whole requirement, so the sort lives here and nowhere else.
        val (firstId, secondId) =
            listOf(command.senderWalletId, command.recipientWalletId).sorted()

        val first = lockWallet(firstId)
        val second = lockWallet(secondId)

        val sender = if (firstId == command.senderWalletId) first else second
        val recipient = if (firstId == command.senderWalletId) second else first

        if (sender.balance < command.amount) {
            throw InsufficientFundsException(sender.id, sender.balance, command.amount)
        }

        sender.balance -= command.amount
        recipient.balance += command.amount

        // Saved last, inside the same transaction. If the idempotency key is already
        // taken this insert raises 23505 and takes the two balance writes down with it,
        // which is exactly the behaviour a duplicate request should have.
        return transferRepository.save(
            Transfer(
                id = UUID.randomUUID(),
                idempotencyKey = command.idempotencyKey,
                requestFingerprint = command.fingerprint(),
                senderWalletId = sender.id,
                recipientWalletId = recipient.id,
                amount = command.amount,
                senderBalanceAfter = sender.balance,
                status = TransferStatus.COMPLETED,
            ),
        )
    }

    private fun lockWallet(id: UUID) =
        walletRepository.findByIdWithPessimisticWriteLock(id)
            ?: throw WalletNotFoundException(id)
}

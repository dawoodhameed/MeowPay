package co.meowpay.service

import java.util.UUID

/**
 * Failures the ledger raises deliberately. Each maps to one HTTP status and one
 * stable `type` slug in [co.meowpay.web.ApiExceptionHandler], so clients branch on
 * a machine-readable value rather than on message text.
 */
sealed class TransferException(message: String) : RuntimeException(message)

class WalletNotFoundException(val walletId: UUID) :
    TransferException("Wallet $walletId does not exist")

class SelfTransferException :
    TransferException("A cat cannot send treats to itself")

class AmountNotPositiveException(val amount: Long) :
    TransferException("Amount must be greater than zero, got $amount")

class InsufficientFundsException(
    val walletId: UUID,
    val balance: Long,
    val requested: Long,
) : TransferException("Wallet $walletId holds $balance treats, cannot send $requested")

/**
 * The idempotency key was already used for a *different* transfer.
 *
 * Without the fingerprint check this case would silently return the earlier
 * transfer with a 200, and the caller would believe a transfer happened that never
 * did. Surfacing it as a conflict makes a client-side key-reuse bug loud.
 */
class IdempotencyKeyReuseException(val idempotencyKey: String) :
    TransferException("Idempotency key $idempotencyKey was already used for a different transfer")

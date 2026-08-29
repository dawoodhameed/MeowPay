package co.meowpay.web

import co.meowpay.domain.Transfer
import jakarta.validation.constraints.NotNull
import jakarta.validation.constraints.Positive
import java.time.Instant
import java.util.UUID

data class CreateTransferRequest(
    @field:NotNull(message = "senderWalletId is required")
    val senderWalletId: UUID?,
    @field:NotNull(message = "recipientWalletId is required")
    val recipientWalletId: UUID?,
    @field:NotNull(message = "amount is required")
    @field:Positive(message = "amount must be greater than zero")
    val amount: Long?,
)

/**
 * `amount` and `senderBalanceAfter` serialise as JSON numbers rather than strings.
 * A `bigint` can exceed JavaScript's safe integer range above 2^53, but treat balances
 * are nowhere near it, and string-typed amounts would push parsing onto both clients to
 * guard a case that cannot arise here. If treats ever become a real currency in minor
 * units, this is the decision to revisit.
 */
data class TransferResponse(
    val id: UUID,
    val senderWalletId: UUID,
    val recipientWalletId: UUID,
    val amount: Long,
    val senderBalanceAfter: Long,
    val status: String,
    val createdAt: Instant,
) {
    companion object {
        fun from(transfer: Transfer) =
            TransferResponse(
                id = transfer.id,
                senderWalletId = transfer.senderWalletId,
                recipientWalletId = transfer.recipientWalletId,
                amount = transfer.amount,
                senderBalanceAfter = transfer.senderBalanceAfter,
                status = transfer.status.name,
                createdAt = transfer.createdAt,
            )
    }
}

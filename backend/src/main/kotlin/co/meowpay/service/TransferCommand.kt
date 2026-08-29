package co.meowpay.service

import co.meowpay.domain.Transfer
import java.security.MessageDigest
import java.util.UUID

data class TransferCommand(
    val senderWalletId: UUID,
    val recipientWalletId: UUID,
    val amount: Long,
    val idempotencyKey: String,
) {
    /**
     * SHA-256 over the fields that define *which* transfer this is. Two requests
     * carrying the same idempotency key are the same intent only if this matches;
     * if it differs, the client reused a key for different money.
     */
    fun fingerprint(): String {
        val canonical = "$senderWalletId:$recipientWalletId:$amount"
        return MessageDigest.getInstance("SHA-256")
            .digest(canonical.toByteArray())
            .joinToString("") { "%02x".format(it) }
    }
}

/**
 * [replayed] distinguishes a transfer this request created from one an earlier
 * request created, so the controller can answer 201 or 200 accordingly.
 */
data class TransferResult(
    val transfer: Transfer,
    val replayed: Boolean,
)

package co.meowpay.web

import co.meowpay.repository.CatWithWalletRow
import co.meowpay.repository.TransferLedgerRow
import java.time.Instant
import java.util.UUID

data class CatResponse(
    val id: UUID,
    val name: String,
    val accountNumber: String,
    val avatarUrl: String?,
    val walletId: UUID,
    val balance: Long,
) {
    companion object {
        fun from(row: CatWithWalletRow) =
            CatResponse(
                id = row.catId,
                name = row.catName,
                accountNumber = row.accountNumber,
                avatarUrl = row.avatarUrl,
                walletId = row.walletId,
                balance = row.balance,
            )
    }
}

data class WalletResponse(
    val id: UUID,
    val catId: UUID,
    val balance: Long,
)

data class LedgerPartyResponse(
    val walletId: UUID,
    val catName: String,
)

/**
 * Both parties are named inline so the ledger table renders from one response. Returning
 * bare wallet ids would push a lookup per row onto the client.
 */
data class LedgerEntryResponse(
    val id: UUID,
    val amount: Long,
    val status: String,
    val createdAt: Instant,
    val sender: LedgerPartyResponse,
    val recipient: LedgerPartyResponse,
) {
    companion object {
        fun from(row: TransferLedgerRow) =
            LedgerEntryResponse(
                id = row.id,
                amount = row.amount,
                status = row.status,
                createdAt = row.createdAt,
                sender = LedgerPartyResponse(row.senderWalletId, row.senderCatName),
                recipient = LedgerPartyResponse(row.recipientWalletId, row.recipientCatName),
            )
    }
}

/**
 * [nextCursor] is null on the last page. Clients paginate by echoing it back rather than
 * tracking an offset, so a transfer committing between page loads cannot shift rows out
 * of view.
 */
data class LedgerPageResponse(
    val items: List<LedgerEntryResponse>,
    val nextCursor: String?,
)

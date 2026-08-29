package co.meowpay.service

import co.meowpay.repository.CatRepository
import co.meowpay.repository.CatWithWalletRow
import co.meowpay.repository.TransferLedgerRow
import co.meowpay.repository.TransferRepository
import co.meowpay.repository.WalletRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.UUID

data class LedgerPage(
    val items: List<TransferLedgerRow>,
    val nextCursor: String?,
)

/**
 * Read side of the ledger. Separate from [TransferService] because these queries take
 * no locks and mutate nothing: keeping them apart stops a reporting query drifting into
 * the path that moves money.
 */
@Service
@Transactional(readOnly = true)
class LedgerQueryService(
    private val catRepository: CatRepository,
    private val walletRepository: WalletRepository,
    private val transferRepository: TransferRepository,
) {
    fun listCats(): List<CatWithWalletRow> = catRepository.findAllWithWallets()

    /**
     * Payee lookup. Returning the name lets the client show *who* is about to be
     * paid before the sender commits to it -- the check that catches a mistyped
     * digit while it is still free to catch.
     */
    fun findByAccountNumber(accountNumber: String): CatWithWalletRow =
        catRepository.findByAccountNumber(accountNumber)
            ?: throw AccountNotFoundException(accountNumber)

    fun getWallet(walletId: UUID) = walletRepository.findById(walletId).orElseThrow { WalletNotFoundException(walletId) }

    fun listTransfers(
        walletId: UUID?,
        cursor: String?,
        limit: Int,
    ): LedgerPage {
        val decoded = cursor?.let { LedgerCursor.decode(it) }

        // One row beyond the page tells us whether another page exists without a second
        // COUNT query, which on a growing ledger would cost more than the page itself.
        val rows =
            transferRepository.findLedgerPage(
                walletId = walletId,
                beforeCreatedAt = decoded?.createdAt,
                beforeId = decoded?.id,
                limit = limit + 1,
            )

        val page = rows.take(limit)
        val nextCursor =
            if (rows.size > limit) {
                page.last().let { LedgerCursor(it.createdAt, it.id).encode() }
            } else {
                null
            }

        return LedgerPage(page, nextCursor)
    }
}

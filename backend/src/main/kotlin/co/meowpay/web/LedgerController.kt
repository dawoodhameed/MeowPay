package co.meowpay.web

import co.meowpay.service.LedgerQueryService
import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Positive
import org.springframework.validation.annotation.Validated
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import java.util.UUID

@RestController
@RequestMapping("/api/v1")
@Validated
class LedgerController(
    private val ledgerQueryService: LedgerQueryService,
) {
    /** Every cat with its wallet and balance -- one call backs both clients' pickers. */
    @GetMapping("/cats")
    fun listCats(): List<CatResponse> = ledgerQueryService.listCats().map(CatResponse::from)

    @GetMapping("/wallets/{walletId}")
    fun getWallet(
        @PathVariable walletId: UUID,
    ): WalletResponse =
        ledgerQueryService.getWallet(walletId).let {
            WalletResponse(id = it.id, catId = it.catId, balance = it.balance)
        }

    /**
     * The ledger, newest first. `walletId` matches a transfer in either direction, since
     * a cat's history is everything it sent *and* received.
     *
     * `limit` is capped rather than unbounded: without a ceiling a client could ask for
     * the entire table in one request, and the cost of that grows with the ledger.
     */
    @GetMapping("/transfers")
    fun listTransfers(
        @RequestParam(required = false) walletId: UUID?,
        @RequestParam(required = false) cursor: String?,
        @RequestParam(defaultValue = "50") @Positive @Max(200) limit: Int,
    ): LedgerPageResponse {
        val page = ledgerQueryService.listTransfers(walletId, cursor, limit)
        return LedgerPageResponse(
            items = page.items.map(LedgerEntryResponse::from),
            nextCursor = page.nextCursor,
        )
    }
}

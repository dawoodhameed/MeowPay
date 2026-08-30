package co.meowpay.web

import co.meowpay.service.LedgerQueryService
import io.swagger.v3.oas.annotations.Operation
import io.swagger.v3.oas.annotations.Parameter
import io.swagger.v3.oas.annotations.responses.ApiResponse
import io.swagger.v3.oas.annotations.responses.ApiResponses
import io.swagger.v3.oas.annotations.tags.Tag
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
@Tag(name = "Ledger", description = "Reading cats, wallets and transfer history")
class LedgerController(
    private val ledgerQueryService: LedgerQueryService,
) {
    /** Every cat with its wallet and balance -- one call backs both clients' pickers. */
    @Operation(
        summary = "List cats",
        description =
            "Every cat with its account number, wallet id and balance. One call backs " +
                "an account switcher, a payee picker and every balance display.",
    )
    @GetMapping("/cats")
    fun listCats(): List<CatResponse> = ledgerQueryService.listCats().map(CatResponse::from)

    /**
     * Resolves the account number a sender typed into the payee it belongs to, so
     * the app can show who is about to be paid before the sender commits.
     */
    @Operation(
        summary = "Look up a payee by account number",
        description =
            "Resolves the number a sender typed into the cat that holds it, so the app can " +
                "confirm who is about to be paid before the sender commits to it.",
    )
    @ApiResponses(
        ApiResponse(responseCode = "200", description = "The cat holding this account"),
        ApiResponse(responseCode = "404", description = "No cat holds that account number"),
    )
    @GetMapping("/cats/by-account/{accountNumber}")
    fun findByAccountNumber(
        @PathVariable accountNumber: String,
    ): CatResponse = CatResponse.from(ledgerQueryService.findByAccountNumber(accountNumber))

    @Operation(summary = "Get a wallet balance")
    @ApiResponses(
        ApiResponse(responseCode = "200", description = "The wallet"),
        ApiResponse(responseCode = "404", description = "No such wallet"),
    )
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
    @Operation(
        summary = "List transfers",
        description = """
            The ledger, newest first.

            Paginated by keyset rather than offset: a transfer committing between two page
            loads would otherwise shift every later row down by one and the reader would
            silently never see one.

            Pass back `nextCursor` from the previous response to fetch the next page. It is
            opaque — echo it unmodified rather than constructing one. A null `nextCursor`
            means there are no more pages.
            """,
    )
    @ApiResponses(
        ApiResponse(responseCode = "200", description = "One page of the ledger"),
        ApiResponse(
            responseCode = "400",
            description = "Malformed cursor (invalid-cursor), or limit outside 1..200",
        ),
    )
    @GetMapping("/transfers")
    fun listTransfers(
        @Parameter(description = "Only transfers where this wallet is sender *or* recipient")
        @RequestParam(required = false) walletId: UUID?,
        @Parameter(description = "nextCursor from a previous response, passed back unmodified")
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

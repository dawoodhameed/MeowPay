package co.meowpay.web

import co.meowpay.service.TransferCommand
import co.meowpay.service.TransferService
import io.swagger.v3.oas.annotations.Operation
import io.swagger.v3.oas.annotations.Parameter
import io.swagger.v3.oas.annotations.responses.ApiResponse
import io.swagger.v3.oas.annotations.responses.ApiResponses
import io.swagger.v3.oas.annotations.tags.Tag
import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.validation.annotation.Validated
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1/transfers")
@Validated
@Tag(name = "Transfers", description = "Moving treats between wallets")
class TransferController(
    private val transferService: TransferService,
) {
    /**
     * The idempotency key is a required header rather than a body field: it describes
     * how to *handle* the request rather than what to transfer, and keeping it in the
     * header lets every future state-changing endpoint carry it the same way.
     *
     * A first execution answers 201; a replay answers 200 with the original transfer
     * and an `Idempotency-Replayed` header, so a client can tell the two apart without
     * comparing bodies.
     */
    @Operation(
        summary = "Send treats",
        description = """
            Moves treats from one wallet to another. The debit, the credit and the ledger
            row commit in a single transaction, so a failure leaves nothing half-applied.

            Both wallets are locked in ascending id order, which is what stops two
            transfers in opposite directions between the same pair from deadlocking.

            Supply the same `X-Idempotency-Key` when retrying a request whose outcome you
            did not learn. A retry is then recognised rather than becoming a second
            transfer.
            """,
    )
    @ApiResponses(
        ApiResponse(responseCode = "201", description = "Transfer created"),
        ApiResponse(
            responseCode = "200",
            description =
                "This idempotency key was already used for an identical request. " +
                    "The original transfer is returned unchanged, with Idempotency-Replayed: true.",
        ),
        ApiResponse(
            responseCode = "400",
            description = "Malformed request: missing key, bad UUID, absent or non-integer amount",
        ),
        ApiResponse(responseCode = "404", description = "Sender or recipient wallet does not exist"),
        ApiResponse(
            responseCode = "409",
            description = "This key was already used for a *different* transfer (type: idempotency-key-reuse)",
        ),
        ApiResponse(
            responseCode = "422",
            description =
                "Well-formed but refused: insufficient-funds (carries the current balance), " +
                    "self-transfer, or amount-not-positive",
        ),
        ApiResponse(
            responseCode = "503",
            description = "A wallet lock could not be acquired. Retryable; should be unreachable.",
        ),
    )
    @PostMapping
    fun createTransfer(
        @Parameter(
            description =
                "Identifies the user's intent, not the HTTP call. Generate one per send " +
                    "and reuse it across retries of that same send.",
            required = true,
            example = "8f14e45f-ea0d-4f1c-9b2a-7d3c1e5a90bb",
        )
        @RequestHeader("X-Idempotency-Key")
        @NotBlank(message = "X-Idempotency-Key must not be blank")
        idempotencyKey: String,
        @Valid @RequestBody request: CreateTransferRequest,
    ): ResponseEntity<TransferResponse> {
        val result =
            transferService.transfer(
                TransferCommand(
                    // Non-null by validation: @Valid rejects the request before this runs.
                    senderWalletId = request.senderWalletId!!,
                    recipientWalletId = request.recipientWalletId!!,
                    amount = request.amount!!,
                    idempotencyKey = idempotencyKey,
                ),
            )

        val status = if (result.replayed) HttpStatus.OK else HttpStatus.CREATED
        return ResponseEntity.status(status)
            .header("Idempotency-Replayed", result.replayed.toString())
            .body(TransferResponse.from(result.transfer))
    }
}

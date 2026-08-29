package co.meowpay.web

import co.meowpay.service.TransferCommand
import co.meowpay.service.TransferService
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
    @PostMapping
    fun createTransfer(
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

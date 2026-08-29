package co.meowpay.web

import co.meowpay.service.AmountNotPositiveException
import co.meowpay.service.IdempotencyKeyReuseException
import co.meowpay.service.InsufficientFundsException
import co.meowpay.service.SelfTransferException
import co.meowpay.service.WalletNotFoundException
import jakarta.servlet.http.HttpServletRequest
import org.springframework.dao.CannotAcquireLockException
import org.springframework.http.HttpStatus
import org.springframework.http.ProblemDetail
import org.springframework.web.bind.MethodArgumentNotValidException
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.RestControllerAdvice
import java.net.URI

/**
 * Maps ledger failures to RFC 9457 `application/problem+json`.
 *
 * Every response carries a stable `type` slug so clients branch on a machine-readable
 * value; message text is for humans and may be reworded at any time.
 *
 * The 400/422 split is deliberate. 400 means the request was malformed and the client
 * has a bug. 422 means it was well-formed and the ledger refused it -- insufficient
 * funds, a self-transfer -- which is a state the user should see explained. Collapsing
 * both into 400 would force clients to parse messages to tell a bug from a decline.
 */
@RestControllerAdvice
class ApiExceptionHandler {
    @ExceptionHandler(MethodArgumentNotValidException::class)
    fun onValidationFailure(
        e: MethodArgumentNotValidException,
        request: HttpServletRequest,
    ): ProblemDetail {
        val fieldErrors =
            e.bindingResult.fieldErrors.associate {
                it.field to (it.defaultMessage ?: "is invalid")
            }
        return problem(
            status = HttpStatus.BAD_REQUEST,
            type = "validation-failed",
            title = "Request is not valid",
            detail = "The request body failed validation",
            request = request,
        ).apply { setProperty("errors", fieldErrors) }
    }

    @ExceptionHandler(WalletNotFoundException::class)
    fun onWalletNotFound(
        e: WalletNotFoundException,
        request: HttpServletRequest,
    ) = problem(
        status = HttpStatus.NOT_FOUND,
        type = "wallet-not-found",
        title = "Wallet not found",
        detail = e.message,
        request = request,
    ).apply { setProperty("walletId", e.walletId.toString()) }

    @ExceptionHandler(SelfTransferException::class)
    fun onSelfTransfer(
        e: SelfTransferException,
        request: HttpServletRequest,
    ) = problem(
        status = HttpStatus.UNPROCESSABLE_ENTITY,
        type = "self-transfer",
        title = "Cannot send treats to yourself",
        detail = e.message,
        request = request,
    )

    @ExceptionHandler(AmountNotPositiveException::class)
    fun onAmountNotPositive(
        e: AmountNotPositiveException,
        request: HttpServletRequest,
    ) = problem(
        status = HttpStatus.UNPROCESSABLE_ENTITY,
        type = "amount-not-positive",
        title = "Amount must be positive",
        detail = e.message,
        request = request,
    )

    /**
     * Carries the current balance, so the client can say "Whiskers only has 12 treats"
     * without a second request.
     */
    @ExceptionHandler(InsufficientFundsException::class)
    fun onInsufficientFunds(
        e: InsufficientFundsException,
        request: HttpServletRequest,
    ) = problem(
        status = HttpStatus.UNPROCESSABLE_ENTITY,
        type = "insufficient-funds",
        title = "Not enough treats",
        detail = e.message,
        request = request,
    ).apply {
        setProperty("walletId", e.walletId.toString())
        setProperty("balance", e.balance)
        setProperty("requested", e.requested)
    }

    @ExceptionHandler(IdempotencyKeyReuseException::class)
    fun onIdempotencyKeyReuse(
        e: IdempotencyKeyReuseException,
        request: HttpServletRequest,
    ) = problem(
        status = HttpStatus.CONFLICT,
        type = "idempotency-key-reuse",
        title = "Idempotency key already used for a different transfer",
        detail = e.message,
        request = request,
    )

    /**
     * A wallet row could not be locked within `lock_timeout`, or Postgres aborted this
     * transaction to break a deadlock.
     *
     * Ordered lock acquisition should make deadlock unreachable, so this firing in
     * production means an invariant has been broken -- a second code path locking
     * wallets in a different order, most likely. It is mapped rather than left to
     * surface as a 500 because the transaction rolled back cleanly and the request is
     * genuinely safe to retry, which a 500 does not tell the client.
     */
    @ExceptionHandler(CannotAcquireLockException::class)
    fun onLockAcquisitionFailure(
        e: CannotAcquireLockException,
        request: HttpServletRequest,
    ): ProblemDetail =
        problem(
            status = HttpStatus.SERVICE_UNAVAILABLE,
            type = "lock-timeout",
            title = "Could not acquire wallet lock",
            detail = "The transfer could not be completed because a wallet was locked. Retry.",
            request = request,
        )

    private fun problem(
        status: HttpStatus,
        type: String,
        title: String,
        detail: String?,
        request: HttpServletRequest,
    ): ProblemDetail =
        ProblemDetail.forStatus(status).apply {
            this.type = URI.create("https://meowpay.co/problems/$type")
            this.title = title
            this.detail = detail
            this.instance = URI.create(request.requestURI)
        }
}

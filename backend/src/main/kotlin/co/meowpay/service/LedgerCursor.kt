package co.meowpay.service

import java.time.Instant
import java.util.Base64
import java.util.UUID

/**
 * Opaque pointer to the last row of a page.
 *
 * Encoded rather than exposed as two query parameters so clients treat it as a token
 * to echo back, not a value to construct. That keeps the pagination key an internal
 * detail: adding a tiebreaker or changing the sort later does not break a client that
 * only ever passes back what it was given.
 */
data class LedgerCursor(
    val createdAt: Instant,
    val id: UUID,
) {
    fun encode(): String =
        Base64.getUrlEncoder().withoutPadding()
            .encodeToString("$createdAt|$id".toByteArray())

    companion object {
        fun decode(raw: String): LedgerCursor =
            try {
                val (timestamp, id) = String(Base64.getUrlDecoder().decode(raw)).split("|", limit = 2)
                LedgerCursor(Instant.parse(timestamp), UUID.fromString(id))
            } catch (e: IllegalArgumentException) {
                throw InvalidCursorException(raw, e)
            } catch (e: IndexOutOfBoundsException) {
                throw InvalidCursorException(raw, e)
            } catch (e: java.time.format.DateTimeParseException) {
                throw InvalidCursorException(raw, e)
            }
    }
}

class InvalidCursorException(val cursor: String, cause: Throwable) :
    RuntimeException("Cursor '$cursor' is not a valid page token", cause)

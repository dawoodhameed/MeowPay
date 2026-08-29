package co.meowpay.repository

import co.meowpay.domain.Transfer
import org.springframework.data.jpa.repository.JpaRepository
import java.util.UUID

interface TransferRepository : JpaRepository<Transfer, UUID> {
    /**
     * Reads back the transfer that won a race for an idempotency key.
     *
     * This is **not** a pre-flight check. Calling it before an insert to decide
     * whether to proceed is check-then-act, and loses the race it exists to prevent:
     * two concurrent requests with the same key both see null and both continue. The
     * unique index is what actually serialises them.
     *
     * Its correct use is the replay path -- after an insert has failed with a unique
     * violation, and in a *new* transaction, because Postgres aborts the whole
     * transaction on any statement error and a query issued on the poisoned one fails
     * with `25P02`.
     */
    fun findByIdempotencyKey(idempotencyKey: String): Transfer?
}

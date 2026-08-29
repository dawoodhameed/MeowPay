package co.meowpay.repository

import co.meowpay.domain.Transfer
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.time.Instant
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

    /**
     * One page of the ledger, newest first, with both parties' names resolved.
     *
     * Paginated by keyset rather than OFFSET. Offset pagination re-counts the skipped
     * rows on every page, so it degrades as the ledger grows, and -- worse for a live
     * feed -- a transfer committing between two page loads shifts every later row down
     * by one, so the reader silently never sees one. Comparing against the last row's
     * (created_at, id) is stable under concurrent inserts and uses the existing index.
     *
     * The id is part of the key because created_at is not unique: two transfers
     * committing in the same microsecond would otherwise make the cursor ambiguous and
     * could drop or repeat one of them.
     *
     * A wallet matches as either party, which is why both directional indexes exist.
     */
    @Query(
        value = """
            SELECT t.id                                  AS "id",
                   t.amount                              AS "amount",
                   t.status                              AS "status",
                   t.created_at                          AS "createdAt",
                   t.sender_wallet_id                    AS "senderWalletId",
                   sc.name                               AS "senderCatName",
                   t.recipient_wallet_id                 AS "recipientWalletId",
                   rc.name                               AS "recipientCatName"
            FROM transfers t
            JOIN wallets sw ON sw.id = t.sender_wallet_id
            JOIN cats    sc ON sc.id = sw.cat_id
            JOIN wallets rw ON rw.id = t.recipient_wallet_id
            JOIN cats    rc ON rc.id = rw.cat_id
            WHERE (CAST(:walletId AS uuid) IS NULL
                   OR t.sender_wallet_id = CAST(:walletId AS uuid)
                   OR t.recipient_wallet_id = CAST(:walletId AS uuid))
              AND (CAST(:beforeCreatedAt AS timestamptz) IS NULL
                   OR (t.created_at, t.id) < (CAST(:beforeCreatedAt AS timestamptz), CAST(:beforeId AS uuid)))
            ORDER BY t.created_at DESC, t.id DESC
            LIMIT :limit
        """,
        nativeQuery = true,
    )
    fun findLedgerPage(
        @Param("walletId") walletId: UUID?,
        @Param("beforeCreatedAt") beforeCreatedAt: Instant?,
        @Param("beforeId") beforeId: UUID?,
        @Param("limit") limit: Int,
    ): List<TransferLedgerRow>
}

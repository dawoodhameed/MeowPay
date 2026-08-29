package co.meowpay.domain

import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.EnumType
import jakarta.persistence.Enumerated
import jakarta.persistence.Id
import jakarta.persistence.Table
import java.time.Instant
import java.util.UUID

/**
 * An immutable ledger line, written in the same transaction as the two balance
 * mutations it describes. A transfer row existing *is* the proof the money moved:
 * if the transaction rolls back, the row goes with it.
 *
 * Every field is `val`. Transfers are never updated and never deleted -- correcting
 * one means writing a compensating transfer, so the history stays auditable.
 */
@Entity
@Table(name = "transfers")
class Transfer(
    @Id
    @Column(name = "id", nullable = false, updatable = false)
    val id: UUID,
    /**
     * Unique across the table. This constraint, not any application-level check, is
     * what makes concurrent duplicate requests safe: two requests carrying the same
     * key both pass a `SELECT`, and the index is what forces one of them to lose.
     */
    @Column(name = "idempotency_key", nullable = false, updatable = false)
    val idempotencyKey: String,
    /**
     * SHA-256 over sender, recipient and amount. Lets the replay path tell a genuine
     * retry from a client reusing one key for a different transfer, which would
     * otherwise silently return the wrong transfer.
     */
    @Column(name = "request_fingerprint", nullable = false, updatable = false)
    val requestFingerprint: String,
    @Column(name = "sender_wallet_id", nullable = false, updatable = false)
    val senderWalletId: UUID,
    @Column(name = "recipient_wallet_id", nullable = false, updatable = false)
    val recipientWalletId: UUID,
    @Column(name = "amount", nullable = false, updatable = false)
    val amount: Long,
    /**
     * The sender's balance immediately after this transfer committed. Stored rather
     * than derived so a replay returns the original figure: a balance read at replay
     * time reflects every transfer since, not this one.
     */
    @Column(name = "sender_balance_after", nullable = false, updatable = false)
    val senderBalanceAfter: Long,
    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, updatable = false)
    val status: TransferStatus,
    @Column(name = "created_at", nullable = false, updatable = false)
    val createdAt: Instant = Instant.now(),
)

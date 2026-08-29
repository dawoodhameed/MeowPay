package co.meowpay.domain

import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.Id
import jakarta.persistence.Table
import org.hibernate.annotations.UpdateTimestamp
import java.time.Instant
import java.util.UUID

/**
 * The single source of financial truth.
 *
 * [balance] counts whole treats as a [Long]. There is no fractional treat, and so
 * no rounding policy to get wrong -- the type itself rules out a class of bug that
 * a floating-point balance would leave open.
 *
 * It is the only mutable field on the only mutable entity in the ledger, and it is
 * only ever written while the row is held under a pessimistic write lock. See
 * `WalletRepository.findByIdWithPessimisticWriteLock`.
 *
 * The database enforces `balance >= 0` independently of anything Kotlin does.
 */
@Entity
@Table(name = "wallets")
class Wallet(
    @Id
    @Column(name = "id", nullable = false, updatable = false)
    val id: UUID,
    @Column(name = "cat_id", nullable = false, updatable = false)
    val catId: UUID,
    @Column(name = "balance", nullable = false)
    var balance: Long,
    @Column(name = "created_at", nullable = false, updatable = false)
    val createdAt: Instant = Instant.now(),
    /**
     * Maintained by Hibernate on every flush. The column's `DEFAULT now()` only
     * fires on insert, so without this the timestamp would keep reporting the
     * wallet's creation time no matter how often its balance changed -- a field
     * on a financial table that quietly lies about when money last moved.
     */
    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    var updatedAt: Instant = Instant.now(),
)

package co.meowpay.domain

import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.Id
import jakarta.persistence.Table
import java.time.Instant
import java.util.UUID

/**
 * A cat's identity. Deliberately holds no balance: money lives in [Wallet], so a
 * cat can later hold more than one wallet without reshaping this table.
 */
@Entity
@Table(name = "cats")
class Cat(
    @Id
    @Column(name = "id", nullable = false, updatable = false)
    val id: UUID,
    @Column(name = "name", nullable = false)
    val name: String,
    @Column(name = "avatar_url")
    val avatarUrl: String? = null,
    @Column(name = "created_at", nullable = false, updatable = false)
    val createdAt: Instant = Instant.now(),
)

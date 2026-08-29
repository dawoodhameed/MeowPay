package co.meowpay.repository

import co.meowpay.domain.Cat
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import java.util.UUID

interface CatRepository : JpaRepository<Cat, UUID> {
    /**
     * Every cat with its wallet, ordered by name so the clients' pickers are stable
     * between reloads rather than following insertion order.
     */
    @Query(
        value = """
            SELECT c.id            AS "catId",
                   c.name          AS "catName",
                   c.avatar_url    AS "avatarUrl",
                   w.id            AS "walletId",
                   w.balance       AS "balance"
            FROM cats c
            JOIN wallets w ON w.cat_id = c.id
            ORDER BY c.name
        """,
        nativeQuery = true,
    )
    fun findAllWithWallets(): List<CatWithWalletRow>
}

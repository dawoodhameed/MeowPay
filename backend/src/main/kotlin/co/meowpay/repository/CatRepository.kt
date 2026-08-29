package co.meowpay.repository

import co.meowpay.domain.Cat
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.util.UUID

interface CatRepository : JpaRepository<Cat, UUID> {
    /**
     * Every cat with its wallet, ordered by name so the clients' pickers are stable
     * between reloads rather than following insertion order.
     */
    @Query(
        value = """
            SELECT c.id             AS "catId",
                   c.name           AS "catName",
                   c.account_number AS "accountNumber",
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

    /**
     * Resolves a payee from the number a sender typed.
     *
     * Deliberately server-side rather than filtering the cat list in the client:
     * a client-side match only works while every account is already on the device,
     * which stops being true the moment there is more than a demo's worth of them.
     */
    @Query(
        value = """
            SELECT c.id             AS "catId",
                   c.name           AS "catName",
                   c.account_number AS "accountNumber",
                   c.avatar_url     AS "avatarUrl",
                   w.id             AS "walletId",
                   w.balance        AS "balance"
            FROM cats c
            JOIN wallets w ON w.cat_id = c.id
            WHERE c.account_number = :accountNumber
        """,
        nativeQuery = true,
    )
    fun findByAccountNumber(
        @Param("accountNumber") accountNumber: String,
    ): CatWithWalletRow?
}

package co.meowpay.support

import co.meowpay.domain.Cat
import co.meowpay.domain.Wallet
import co.meowpay.repository.CatRepository
import co.meowpay.repository.WalletRepository
import org.springframework.jdbc.core.JdbcTemplate
import org.springframework.stereotype.Component
import java.util.UUID

/**
 * Creates ledger fixtures and clears them between tests.
 *
 * Cleanup is a `TRUNCATE` rather than a rolled-back transaction, because the tests that
 * matter here run across several threads and several transactions -- there is no single
 * transaction to roll back.
 */
@Component
class LedgerFixture(
    private val catRepository: CatRepository,
    private val walletRepository: WalletRepository,
    private val jdbcTemplate: JdbcTemplate,
) {
    fun resetLedger() {
        jdbcTemplate.execute("TRUNCATE transfers, wallets, cats CASCADE")
        accountSequence = 0
    }

    private var accountSequence = 0

    /** Unique per test, so the account-number index is never the reason a test fails. */
    private fun nextAccountNumber(): String {
        accountSequence += 1
        return "9000%04d".format(accountSequence)
    }

    fun createCatWithWallet(
        name: String,
        balance: Long,
        accountNumber: String = nextAccountNumber(),
    ): Wallet {
        val cat =
            catRepository.save(
                Cat(id = UUID.randomUUID(), name = name, accountNumber = accountNumber),
            )
        return walletRepository.save(
            Wallet(id = UUID.randomUUID(), catId = cat.id, balance = balance),
        )
    }

    fun balanceOf(walletId: UUID): Long =
        jdbcTemplate.queryForObject(
            "SELECT balance FROM wallets WHERE id = ?",
            Long::class.java,
            walletId,
        )!!

    fun totalTreats(): Long = jdbcTemplate.queryForObject("SELECT COALESCE(SUM(balance), 0) FROM wallets", Long::class.java)!!

    fun transferCount(): Long = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM transfers", Long::class.java)!!

    /**
     * Writes a balance directly, bypassing every application-level check, so a test can
     * prove the database constraint holds on its own.
     */
    fun forceBalance(
        walletId: UUID,
        balance: Long,
    ) {
        jdbcTemplate.update("UPDATE wallets SET balance = ? WHERE id = ?", balance, walletId)
    }
}

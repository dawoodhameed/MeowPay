package co.meowpay.ledger

import co.meowpay.service.InsufficientFundsException
import co.meowpay.service.TransferCommand
import co.meowpay.service.TransferService
import co.meowpay.support.IntegrationTest
import co.meowpay.support.LedgerFixture
import co.meowpay.support.runConcurrently
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.dao.DataIntegrityViolationException

/**
 * The tests the locking design exists for. Each one fails against an implementation
 * that is correct single-threaded, which is the only reason they are worth running.
 */
class TransferConcurrencyTest
    @Autowired
    constructor(
        private val transferService: TransferService,
        private val fixture: LedgerFixture,
    ) : IntegrationTest() {
        @BeforeEach
        fun reset() {
            fixture.resetLedger()
        }

        /**
         * Ten simultaneous attempts to send 80 treats from a wallet holding 100.
         *
         * Exactly one can succeed. Without `SELECT ... FOR UPDATE` every thread reads
         * 100, every thread finds it sufficient, and the wallet ends up overdrawn --
         * inside a transaction, and without any thread seeing an error.
         */
        @Test
        fun `allows only one of ten concurrent overlapping transfers to succeed`() {
            val whiskers = fixture.createCatWithWallet("Whiskers", balance = 100)
            val mittens = fixture.createCatWithWallet("Mittens", balance = 0)

            val results =
                runConcurrently(10) { i ->
                    transferService.transfer(
                        TransferCommand(whiskers.id, mittens.id, amount = 80, idempotencyKey = "spend-$i"),
                    )
                }

            val succeeded = results.count { it.isSuccess }
            val rejected = results.count { it.exceptionOrNull() is InsufficientFundsException }

            assertThat(succeeded).isEqualTo(1)
            assertThat(rejected).isEqualTo(9)
            assertThat(fixture.balanceOf(whiskers.id)).isEqualTo(20)
            assertThat(fixture.balanceOf(mittens.id)).isEqualTo(80)
            assertThat(fixture.transferCount()).isEqualTo(1)
        }

        /**
         * Twenty simultaneous requests carrying one shared idempotency key.
         *
         * No application-level check can serialise these: every thread would pass a
         * pre-flight `SELECT` before any of them inserted. The unique index is what
         * forces nineteen of them onto the replay path.
         */
        @Test
        fun `collapses twenty concurrent requests sharing one idempotency key into one transfer`() {
            val whiskers = fixture.createCatWithWallet("Whiskers", balance = 1000)
            val mittens = fixture.createCatWithWallet("Mittens", balance = 0)
            val command = TransferCommand(whiskers.id, mittens.id, amount = 30, idempotencyKey = "shared")

            val results = runConcurrently(20) { transferService.transfer(command) }

            assertThat(results).allMatch { it.isSuccess }
            assertThat(results.count { it.getOrThrow().replayed }).isEqualTo(19)
            assertThat(results.map { it.getOrThrow().transfer.id }.distinct()).hasSize(1)

            // Debited exactly once, however many callers were told it succeeded.
            assertThat(fixture.balanceOf(whiskers.id)).isEqualTo(970)
            assertThat(fixture.transferCount()).isEqualTo(1)
        }

        /**
         * Transfers running in both directions between the same pair at once.
         *
         * This is the test that fails if lock ordering is dropped: locking
         * sender-then-recipient leaves each transaction holding the row the other needs,
         * and Postgres aborts one side with SQLSTATE 40P01. Sorting the ids removes the
         * cycle, so every transfer completes.
         */
        @Test
        fun `survives bidirectional contention without deadlocking`() {
            val whiskers = fixture.createCatWithWallet("Whiskers", balance = 5_000)
            val mittens = fixture.createCatWithWallet("Mittens", balance = 5_000)

            val results =
                runConcurrently(20) { i ->
                    val (from, to) =
                        if (i % 2 == 0) whiskers.id to mittens.id else mittens.id to whiskers.id
                    transferService.transfer(
                        TransferCommand(from, to, amount = 1, idempotencyKey = "bidir-$i"),
                    )
                }

            val deadlocked =
                results.count { result ->
                    generateSequence(result.exceptionOrNull()) { it.cause }
                        .any { it.message?.contains("deadlock", ignoreCase = true) == true }
                }

            assertThat(deadlocked).isZero()
            assertThat(results).allMatch { it.isSuccess }
            assertThat(fixture.transferCount()).isEqualTo(20)
            assertThat(fixture.totalTreats()).isEqualTo(10_000)
        }

        /**
         * Treats are moved, never created or destroyed. Asserting the invariant catches
         * a whole class of bug that per-transfer assertions can miss -- a credit applied
         * twice, or a debit lost to a rollback that only partly took effect.
         */
        @Test
        fun `conserves total treats across chaotic concurrent transfers`() {
            val a = fixture.createCatWithWallet("Whiskers", balance = 1_000)
            val b = fixture.createCatWithWallet("Mittens", balance = 1_000)
            val c = fixture.createCatWithWallet("Luna", balance = 1_000)
            val wallets = listOf(a.id, b.id, c.id)

            runConcurrently(30) { i ->
                val from = wallets[i % 3]
                val to = wallets[(i + 1) % 3]
                transferService.transfer(
                    TransferCommand(from, to, amount = (i % 7 + 1).toLong(), idempotencyKey = "chaos-$i"),
                )
            }

            assertThat(fixture.totalTreats()).isEqualTo(3_000)
            wallets.forEach { assertThat(fixture.balanceOf(it)).isGreaterThanOrEqualTo(0) }
        }

        /**
         * The constraint, not the service, is the last line of defence. This writes
         * straight to the table so that if the application check were ever bypassed --
         * a migration, a script, a future code path -- the database still refuses.
         */
        @Test
        fun `database rejects a negative balance written outside the service`() {
            val whiskers = fixture.createCatWithWallet("Whiskers", balance = 10)

            val failure =
                runCatching { fixture.forceBalance(whiskers.id, -1) }.exceptionOrNull()

            assertThat(failure).isInstanceOf(DataIntegrityViolationException::class.java)
            assertThat(failure).hasMessageContaining("wallet_balance_non_negative")
            assertThat(fixture.balanceOf(whiskers.id)).isEqualTo(10)
        }
    }

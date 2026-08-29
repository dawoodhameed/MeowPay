package co.meowpay.ledger

import co.meowpay.service.AccountNotFoundException
import co.meowpay.service.InvalidCursorException
import co.meowpay.service.LedgerQueryService
import co.meowpay.service.TransferCommand
import co.meowpay.service.TransferService
import co.meowpay.service.WalletNotFoundException
import co.meowpay.support.IntegrationTest
import co.meowpay.support.LedgerFixture
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import java.util.UUID

class LedgerQueryServiceTest
    @Autowired
    constructor(
        private val ledgerQueryService: LedgerQueryService,
        private val transferService: TransferService,
        private val fixture: LedgerFixture,
    ) : IntegrationTest() {
        @BeforeEach
        fun reset() {
            fixture.resetLedger()
        }

        @Test
        fun `lists cats with balances, ordered by name`() {
            fixture.createCatWithWallet("Whiskers", balance = 100)
            fixture.createCatWithWallet("Luna", balance = 250)
            fixture.createCatWithWallet("Mittens", balance = 50)

            val cats = ledgerQueryService.listCats()

            assertThat(cats.map { it.catName }).containsExactly("Luna", "Mittens", "Whiskers")
            assertThat(cats.map { it.balance }).containsExactly(250, 50, 100)
            assertThat(cats).allSatisfy { assertThat(it.walletId).isNotNull() }
        }

        @Test
        fun `resolves a payee from an account number`() {
            fixture.createCatWithWallet("Mittens", balance = 50, accountNumber = "10000002")

            val payee = ledgerQueryService.findByAccountNumber("10000002")

            // The name is what the sender confirms before committing to the transfer.
            assertThat(payee.catName).isEqualTo("Mittens")
            assertThat(payee.walletId).isNotNull()
        }

        @Test
        fun `rejects an unknown account number`() {
            assertThatThrownBy {
                ledgerQueryService.findByAccountNumber("00000000")
            }.isInstanceOf(AccountNotFoundException::class.java)
        }

        @Test
        fun `returns an empty ledger rather than failing when nothing has happened`() {
            val page = ledgerQueryService.listTransfers(walletId = null, cursor = null, limit = 50)

            assertThat(page.items).isEmpty()
            assertThat(page.nextCursor).isNull()
        }

        @Test
        fun `lists transfers newest first with both parties named`() {
            val whiskers = fixture.createCatWithWallet("Whiskers", balance = 100)
            val mittens = fixture.createCatWithWallet("Mittens", balance = 100)
            transfer(whiskers.id, mittens.id, 10, "a")
            transfer(mittens.id, whiskers.id, 20, "b")

            val page = ledgerQueryService.listTransfers(null, null, 50)

            assertThat(page.items).hasSize(2)
            // Newest first: the second transfer leads.
            assertThat(page.items.first().amount).isEqualTo(20)
            assertThat(page.items.first().senderCatName).isEqualTo("Mittens")
            assertThat(page.items.first().recipientCatName).isEqualTo("Whiskers")
            assertThat(page.items.last().senderCatName).isEqualTo("Whiskers")
        }

        @Test
        fun `filters by wallet in both directions`() {
            val whiskers = fixture.createCatWithWallet("Whiskers", balance = 100)
            val mittens = fixture.createCatWithWallet("Mittens", balance = 100)
            val luna = fixture.createCatWithWallet("Luna", balance = 100)

            transfer(whiskers.id, mittens.id, 10, "sent")
            transfer(luna.id, whiskers.id, 20, "received")
            transfer(mittens.id, luna.id, 30, "unrelated")

            val page = ledgerQueryService.listTransfers(whiskers.id, null, 50)

            // A cat's history is what it sent *and* what it received -- never just one side.
            assertThat(page.items).hasSize(2)
            assertThat(page.items.map { it.amount }).containsExactlyInAnyOrder(10, 20)
        }

        @Test
        fun `paginates by cursor without repeating or dropping rows`() {
            val whiskers = fixture.createCatWithWallet("Whiskers", balance = 1000)
            val mittens = fixture.createCatWithWallet("Mittens", balance = 0)
            repeat(7) { transfer(whiskers.id, mittens.id, 1, "page-$it") }

            val first = ledgerQueryService.listTransfers(null, null, 3)
            val second = ledgerQueryService.listTransfers(null, first.nextCursor, 3)
            val third = ledgerQueryService.listTransfers(null, second.nextCursor, 3)

            assertThat(first.items).hasSize(3)
            assertThat(second.items).hasSize(3)
            assertThat(third.items).hasSize(1)
            // Last page carries no cursor, so a client knows to stop.
            assertThat(third.nextCursor).isNull()

            val seen = (first.items + second.items + third.items).map { it.id }
            assertThat(seen).doesNotHaveDuplicates()
            assertThat(seen).hasSize(7)
        }

        @Test
        fun `rejects a malformed cursor`() {
            assertThatThrownBy {
                ledgerQueryService.listTransfers(null, "not-a-real-cursor", 50)
            }.isInstanceOf(InvalidCursorException::class.java)
        }

        @Test
        fun `rejects an unknown wallet`() {
            assertThatThrownBy {
                ledgerQueryService.getWallet(UUID.randomUUID())
            }.isInstanceOf(WalletNotFoundException::class.java)
        }

        private fun transfer(
            from: UUID,
            to: UUID,
            amount: Long,
            key: String,
        ) = transferService.transfer(TransferCommand(from, to, amount, key))
    }

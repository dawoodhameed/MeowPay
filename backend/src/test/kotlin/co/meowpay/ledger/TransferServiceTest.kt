package co.meowpay.ledger

import co.meowpay.service.AmountNotPositiveException
import co.meowpay.service.IdempotencyKeyReuseException
import co.meowpay.service.InsufficientFundsException
import co.meowpay.service.SelfTransferException
import co.meowpay.service.TransferCommand
import co.meowpay.service.TransferService
import co.meowpay.service.WalletNotFoundException
import co.meowpay.support.IntegrationTest
import co.meowpay.support.LedgerFixture
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.ValueSource
import org.springframework.beans.factory.annotation.Autowired
import java.util.UUID

class TransferServiceTest
    @Autowired
    constructor(
        private val transferService: TransferService,
        private val fixture: LedgerFixture,
    ) : IntegrationTest() {
        @BeforeEach
        fun reset() {
            fixture.resetLedger()
        }

        @Test
        fun `moves treats from sender to recipient`() {
            val whiskers = fixture.createCatWithWallet("Whiskers", balance = 100)
            val mittens = fixture.createCatWithWallet("Mittens", balance = 50)

            val result =
                transferService.transfer(
                    TransferCommand(whiskers.id, mittens.id, amount = 25, idempotencyKey = "k1"),
                )

            assertThat(result.replayed).isFalse()
            assertThat(result.transfer.amount).isEqualTo(25)
            assertThat(result.transfer.senderBalanceAfter).isEqualTo(75)
            assertThat(fixture.balanceOf(whiskers.id)).isEqualTo(75)
            assertThat(fixture.balanceOf(mittens.id)).isEqualTo(75)
            assertThat(fixture.transferCount()).isEqualTo(1)
        }

        @Test
        fun `rejects a transfer larger than the balance and writes nothing`() {
            val whiskers = fixture.createCatWithWallet("Whiskers", balance = 10)
            val mittens = fixture.createCatWithWallet("Mittens", balance = 0)

            assertThatThrownBy {
                transferService.transfer(
                    TransferCommand(whiskers.id, mittens.id, amount = 11, idempotencyKey = "k1"),
                )
            }.isInstanceOf(InsufficientFundsException::class.java)

            // The rollback has to take the balance writes with it, not just the ledger row.
            assertThat(fixture.balanceOf(whiskers.id)).isEqualTo(10)
            assertThat(fixture.balanceOf(mittens.id)).isEqualTo(0)
            assertThat(fixture.transferCount()).isZero()
        }

        @Test
        fun `rejects a cat sending treats to itself`() {
            val whiskers = fixture.createCatWithWallet("Whiskers", balance = 100)

            assertThatThrownBy {
                transferService.transfer(
                    TransferCommand(whiskers.id, whiskers.id, amount = 10, idempotencyKey = "k1"),
                )
            }.isInstanceOf(SelfTransferException::class.java)

            assertThat(fixture.balanceOf(whiskers.id)).isEqualTo(100)
            assertThat(fixture.transferCount()).isZero()
        }

        @ParameterizedTest
        @ValueSource(longs = [0, -1, -100])
        fun `rejects a non-positive amount`(amount: Long) {
            val whiskers = fixture.createCatWithWallet("Whiskers", balance = 100)
            val mittens = fixture.createCatWithWallet("Mittens", balance = 0)

            assertThatThrownBy {
                transferService.transfer(
                    TransferCommand(whiskers.id, mittens.id, amount, idempotencyKey = "k1"),
                )
            }.isInstanceOf(AmountNotPositiveException::class.java)

            assertThat(fixture.totalTreats()).isEqualTo(100)
        }

        @Test
        fun `rejects an unknown wallet`() {
            val whiskers = fixture.createCatWithWallet("Whiskers", balance = 100)

            assertThatThrownBy {
                transferService.transfer(
                    TransferCommand(whiskers.id, UUID.randomUUID(), amount = 10, idempotencyKey = "k1"),
                )
            }.isInstanceOf(WalletNotFoundException::class.java)

            assertThat(fixture.balanceOf(whiskers.id)).isEqualTo(100)
        }

        @Test
        fun `replays a duplicate key without debiting twice`() {
            val whiskers = fixture.createCatWithWallet("Whiskers", balance = 100)
            val mittens = fixture.createCatWithWallet("Mittens", balance = 0)
            val command = TransferCommand(whiskers.id, mittens.id, amount = 30, idempotencyKey = "same")

            val first = transferService.transfer(command)
            val second = transferService.transfer(command)

            assertThat(first.replayed).isFalse()
            assertThat(second.replayed).isTrue()
            assertThat(second.transfer.id).isEqualTo(first.transfer.id)
            // The replayed figure is the one recorded at commit time, not a fresh read.
            assertThat(second.transfer.senderBalanceAfter).isEqualTo(70)
            assertThat(fixture.balanceOf(whiskers.id)).isEqualTo(70)
            assertThat(fixture.transferCount()).isEqualTo(1)
        }

        @Test
        fun `rejects a key reused for a different transfer`() {
            val whiskers = fixture.createCatWithWallet("Whiskers", balance = 100)
            val mittens = fixture.createCatWithWallet("Mittens", balance = 0)

            transferService.transfer(
                TransferCommand(whiskers.id, mittens.id, amount = 30, idempotencyKey = "shared"),
            )

            // Same key, different money. Returning the earlier transfer here would tell the
            // caller a transfer succeeded that never happened.
            assertThatThrownBy {
                transferService.transfer(
                    TransferCommand(whiskers.id, mittens.id, amount = 31, idempotencyKey = "shared"),
                )
            }.isInstanceOf(IdempotencyKeyReuseException::class.java)

            assertThat(fixture.balanceOf(whiskers.id)).isEqualTo(70)
            assertThat(fixture.transferCount()).isEqualTo(1)
        }
    }

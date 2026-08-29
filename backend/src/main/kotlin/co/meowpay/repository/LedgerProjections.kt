package co.meowpay.repository

import java.time.Instant
import java.util.UUID

/**
 * A cat and its wallet in one row. The clients need the pair together on every
 * screen -- an account switcher, a recipient picker, a balance display -- so joining
 * once here avoids each of them making a second call per cat.
 */
interface CatWithWalletRow {
    val catId: UUID
    val catName: String
    val accountNumber: String
    val avatarUrl: String?
    val walletId: UUID
    val balance: Long
}

/**
 * A ledger line with both parties already resolved.
 *
 * The names are joined in rather than left to the caller on purpose: a ledger table
 * that returns bare wallet ids forces the client into a request per row to render
 * them, which is an N+1 designed into the contract rather than merely tolerated in
 * an implementation.
 */
interface TransferLedgerRow {
    val id: UUID
    val amount: Long
    val status: String
    val createdAt: Instant
    val senderWalletId: UUID
    val senderCatName: String
    val recipientWalletId: UUID
    val recipientCatName: String
}

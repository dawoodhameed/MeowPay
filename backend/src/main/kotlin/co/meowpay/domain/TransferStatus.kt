package co.meowpay.domain

/**
 * Only [COMPLETED] is ever persisted today.
 *
 * Every rejection -- insufficient funds, self-transfer, unknown wallet -- is detected
 * inside the transaction that would have written the transfer row, so the row rolls
 * back with it. A failing transaction cannot write its own epitaph; recording rejected
 * attempts would need a separate `REQUIRES_NEW` transaction, which is deliberately out
 * of scope for this slice.
 *
 * The remaining values exist for the asynchronous states a real payment rail acquires
 * (an external leg that has not settled yet), and to keep that column from needing a
 * migration when it does.
 */
enum class TransferStatus {
    COMPLETED,
    PENDING,
    FAILED,
}

package co.meowpay.repository

import co.meowpay.domain.Wallet
import jakarta.persistence.LockModeType
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Lock
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.util.UUID

interface WalletRepository : JpaRepository<Wallet, UUID> {
    fun findByCatId(catId: UUID): Wallet?

    /**
     * Reads a wallet under `SELECT ... FOR UPDATE`, blocking any other transaction
     * that tries to lock the same row until this one commits or rolls back.
     *
     * Every balance read that precedes a write must go through this method. A plain
     * `findById` on that path is a double-spend hole even inside a transaction:
     * under `READ COMMITTED`, two concurrent transactions will both read the same
     * balance, both find it sufficient, and both debit it.
     *
     * **Callers must acquire locks in ascending wallet id order.** Locking
     * sender-then-recipient deadlocks the moment `A -> B` races `B -> A`, because each
     * transaction ends up holding the row the other needs. A total order over the ids
     * makes that wait-for cycle impossible to construct. This method deliberately
     * locks one wallet at a time so the caller's ordering is explicit at the call
     * site, rather than hidden inside a batch query whose row order is the query
     * planner's choice.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT w FROM Wallet w WHERE w.id = :id")
    fun findByIdWithPessimisticWriteLock(
        @Param("id") id: UUID,
    ): Wallet?
}

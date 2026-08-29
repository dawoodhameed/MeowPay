package co.meowpay.repository

import co.meowpay.domain.Cat
import org.springframework.data.jpa.repository.JpaRepository
import java.util.UUID

interface CatRepository : JpaRepository<Cat, UUID>

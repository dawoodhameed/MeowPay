package co.meowpay.support

import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.testcontainers.service.connection.ServiceConnection
import org.testcontainers.containers.PostgreSQLContainer

/**
 * Base class for tests that exercise the ledger against a real PostgreSQL 16.
 *
 * The database is not optional here. Pessimistic locking, deadlock ordering and
 * unique-constraint recovery are all behaviours of Postgres; an in-memory fake or a
 * mocked repository would pass every test below while the real system lost money.
 *
 * Two settings exist to stop these tests passing for the wrong reason:
 *
 * 1. **This class is deliberately not `@Transactional`.** Spring's test support would
 *    otherwise pin the whole test to one connection and roll it back at the end. Every
 *    thread spawned inside would either share that transaction or be unable to see the
 *    fixture, and the concurrency tests would pass whether or not the locking works.
 *    Cleanup is explicit instead -- see [resetLedger].
 *
 * 2. **The Hikari pool is sized above the highest thread count used.** With a smaller
 *    pool the threads queue for connections rather than for row locks, so the race the
 *    test exists to provoke never happens and the assertion succeeds regardless.
 *
 * The container image matches docker-compose, so what CI proves is what runs locally.
 *
 * The container is started once here and never explicitly stopped, rather than managed by
 * `@Testcontainers`/`@Container`. That extension ties the container's life to a single
 * test class, so with a shared base class the second class inherits an already-stopped
 * container and every test in it fails on connection refused. Testcontainers' own reaper
 * removes the container when the JVM exits.
 */
@SpringBootTest(
    properties = [
        "spring.datasource.hikari.maximum-pool-size=40",
        "spring.flyway.clean-disabled=false",
    ],
)
abstract class IntegrationTest {
    companion object {
        @ServiceConnection
        @JvmStatic
        val postgres: PostgreSQLContainer<*> =
            PostgreSQLContainer("postgres:16")
                .withDatabaseName("meowpay")
                .withUsername("meowpay")
                .withPassword("meowpay")
                .apply { start() }
    }
}

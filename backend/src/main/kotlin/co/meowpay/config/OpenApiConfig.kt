package co.meowpay.config

import io.swagger.v3.oas.models.OpenAPI
import io.swagger.v3.oas.models.info.Info
import io.swagger.v3.oas.models.servers.Server
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration

@Configuration
class OpenApiConfig {
    @Bean
    fun meowPayOpenApi(): OpenAPI =
        OpenAPI()
            .info(
                Info()
                    .title("MeowPay API")
                    .version("v1")
                    .description(
                        """
                        Treat ledger for MeowPay. One cat sends treats to another.

                        ## Money

                        Treats are whole units, held as `bigint`. There are no fractional treats, so
                        every amount and balance is an integer and no rounding policy exists to get
                        wrong.

                        ## Idempotency

                        `POST /transfers` requires an `X-Idempotency-Key` header identifying the
                        **user's intent**, not the HTTP call. Reuse the same key when retrying a
                        request whose outcome you did not learn — a timeout may mean the response was
                        lost rather than that the transfer failed, and reusing the key lets the server
                        replay the original instead of moving treats twice.

                        A first execution answers `201`. A replay answers `200` with the original
                        transfer and an `Idempotency-Replayed: true` header. Reusing a key with a
                        *different* payload answers `409`.

                        Idempotency covers **successful** transfers: a rejected attempt rolls back and
                        releases the key, so retrying it is a fresh attempt.

                        ## Errors

                        Every failure is an RFC 9457 `application/problem+json` document with a stable
                        `type` slug. Branch on `type`, never on `title` or `detail` — those are written
                        for humans and may be reworded.

                        `400` means the request was malformed and the client has a bug. `422` means it
                        was well-formed and the ledger refused it — insufficient funds, a self-transfer
                        — which is a state worth showing the user.
                        """.trimIndent(),
                    ),
            ).servers(
                listOf(
                    Server().url("http://localhost:8080").description("Local Docker stack"),
                ),
            )
}

package co.meowpay

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication

@SpringBootApplication
class MeowPayApplication

fun main(args: Array<String>) {
    runApplication<MeowPayApplication>(*args)
}

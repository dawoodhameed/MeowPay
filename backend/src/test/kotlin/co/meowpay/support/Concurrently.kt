package co.meowpay.support

import java.util.concurrent.Callable
import java.util.concurrent.CyclicBarrier
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Runs [count] copies of [action] as simultaneously as the JVM allows, and returns what
 * each one produced.
 *
 * A [CyclicBarrier] holds every thread until all of them have started, so they contend
 * for the same rows at the same moment. Spawning threads in a loop without one lets the
 * first finish before the last begins, and the test then observes no concurrency at all
 * while still passing.
 *
 * Failures are captured rather than thrown, because a rejected transfer is usually the
 * expected outcome for most threads -- the assertion is on how many succeeded, never on
 * which ones did. Asserting on the identity of the winner would be asserting on thread
 * scheduling, and that flakes.
 */
fun <T> runConcurrently(
    count: Int,
    action: (Int) -> T,
): List<Result<T>> {
    val barrier = CyclicBarrier(count)
    val pool = Executors.newFixedThreadPool(count)
    try {
        val tasks =
            (0 until count).map { index ->
                Callable {
                    barrier.await(30, TimeUnit.SECONDS)
                    runCatching { action(index) }
                }
            }
        return pool.invokeAll(tasks, 120, TimeUnit.SECONDS).map { it.get() }
    } finally {
        pool.shutdownNow()
    }
}

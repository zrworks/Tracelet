import com.ikolvi.tracelet.sdk.model.TraceletConfig

fun main() {
    val map = mapOf(
        "speedStationaryDelay" to 2
    )
    val conf = TraceletConfig.fromMap(map)
    println(conf.motion.speedStationaryDelay)
}

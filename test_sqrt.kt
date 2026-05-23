fun main() {
    val x = 0f
    val y = 0f
    val z = 9.81f
    val magnitude = kotlin.math.sqrt((x * x + y * y + z * z).toDouble()) - 9.81
    println(magnitude)
}

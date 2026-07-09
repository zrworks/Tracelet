package com.ikolvi.tracelet_sync

import com.sun.net.httpserver.HttpServer
import java.net.InetSocketAddress
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Before
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import com.ikolvi.tracelet.sdk.TraceletSdk
import org.mockito.Mockito

class Issue238FallbackSyncTest {

    private var server: HttpServer? = null
    private var port: Int = 0

    @Before
    fun setUp() {
        server = HttpServer.create(InetSocketAddress(0), 0).apply {
            createContext("/sync") { exchange ->
                val response = "Bad Request"
                exchange.sendResponseHeaders(400, response.length.toLong())
                exchange.responseBody.use { os ->
                    os.write(response.toByteArray())
                }
            }
            start()
        }
        port = server!!.address.port
    }

    @After
    fun tearDown() {
        server?.stop(0)
    }

    @Test
    fun testExecuteFallbackHttpSync_returns400FallbackResult() = runBlocking {
        val mockSdk = Mockito.mock(TraceletSdk::class.java)
        val mockLogger = Mockito.mock(com.ikolvi.tracelet.sdk.TraceletLogger::class.java)
        Mockito.`when`(mockSdk.logger).thenReturn(mockLogger)

        val sink = TraceletSyncSink(mockSdk)

        val config = uniffi.tracelet_core.HttpConfig(
            url = "http://127.0.0.1:$port/sync",
            method = 0,
            headers = emptyMap(),
            batchSync = true,
            maxBatchSize = 100,
            autoSync = true,
            maxRetries = 0,
            retryBackoffBase = 1000,
            retryBackoffCap = 10000,
            sslPinningCertificates = emptyList(),
            sslPinningFingerprints = emptyList(),
            httpRootProperty = "locations",
            params = emptyMap(),
            extras = emptyMap(),
            disableAutoSyncOnCellular = false,
            enableDeltaCompression = false,
            deltaCoordinatePrecision = 5,
            locationsOrderDirection = 0
        )

        val result = sink.executeFallbackHttpSync(config, "{\"custom\":true}", null)
        
        assertFalse(result.success)
        assertEquals(400, result.status)
        assertEquals("Bad Request", result.responseText)
    }
}

package com.ikolvi.tracelet.flutter

import android.content.Context
import com.ikolvi.tracelet.TlAuthorizationStatus
import com.ikolvi.tracelet.flutter.service.HeadlessTaskService
import org.junit.Test
import org.mockito.Mockito.mock
import kotlin.test.assertEquals

class TraceletHostApiImplTest {

    @Test
    fun testIntToAuthStatusMapping() {
        val context = mock(Context::class.java)
        val headlessService = mock(HeadlessTaskService::class.java)
        val hostApi = TraceletHostApiImpl(context, headlessService)

        val method = TraceletHostApiImpl::class.java.getDeclaredMethod("intToAuthStatus", Int::class.java)
        method.isAccessible = true

        assertEquals(TlAuthorizationStatus.NOT_DETERMINED, method.invoke(hostApi, 0))
        assertEquals(TlAuthorizationStatus.DENIED, method.invoke(hostApi, 1))
        
        // These two were previously swapped (Issue 80)
        assertEquals(TlAuthorizationStatus.WHEN_IN_USE, method.invoke(hostApi, 2))
        assertEquals(TlAuthorizationStatus.ALWAYS, method.invoke(hostApi, 3))
        
        assertEquals(TlAuthorizationStatus.DENIED_FOREVER, method.invoke(hostApi, 4))
    }
}

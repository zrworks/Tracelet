package com.ikolvi.tracelet.sdk.attestation

import android.content.Context
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest

class PlayIntegrityProvider(context: Context) : IntegrityProvider {
    private val integrityManager = IntegrityManagerFactory.create(context)

    override fun requestToken(
        nonce: String,
        onSuccess: (String) -> Unit,
        onFailure: (Exception) -> Unit
    ) {
        val request = IntegrityTokenRequest.builder()
            .setNonce(nonce)
            .build()

        integrityManager.requestIntegrityToken(request)
            .addOnSuccessListener { response ->
                onSuccess(response.token())
            }
            .addOnFailureListener { e ->
                onFailure(e)
            }
    }
}

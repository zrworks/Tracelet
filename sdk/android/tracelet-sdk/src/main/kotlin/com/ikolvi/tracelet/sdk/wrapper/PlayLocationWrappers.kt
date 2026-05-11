package com.ikolvi.tracelet.sdk.wrapper

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.location.Location
import android.os.Looper
import com.google.android.gms.location.*
import com.google.android.gms.tasks.CancellationTokenSource
import java.util.concurrent.ConcurrentHashMap

class PlayServicesProvider : TraceletServicesProvider {
    override fun getLocationClient(context: Context) = PlayLocationClient(context)
    override fun getGeofencingClient(context: Context) = PlayGeofencingClient(context)
    override fun getActivityRecognitionClient(context: Context) = PlayActivityRecognitionClient(context)
    override fun getEventExtractor() = PlayEventExtractor()
}

class PlayLocationClient(context: Context) : TraceletLocationClient {
    private val fusedClient: FusedLocationProviderClient = LocationServices.getFusedLocationProviderClient(context)
    private val callbackMap = ConcurrentHashMap<TraceletLocationCallback, LocationCallback>()

    @SuppressLint("MissingPermission")
    override fun requestLocationUpdates(request: TraceletLocationRequest, callback: TraceletLocationCallback, looper: Looper) {
        val builder = LocationRequest.Builder(request.priority, request.intervalMillis)
            .setMinUpdateDistanceMeters(request.minUpdateDistanceMeters)
            .setMinUpdateIntervalMillis(request.minUpdateIntervalMillis)
        if (request.maxUpdateDelayMillis > 0) builder.setMaxUpdateDelayMillis(request.maxUpdateDelayMillis)

        val playRequest = builder.build()
        val playCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) { callback.onLocationResult(result.locations) }
            override fun onLocationAvailability(availability: LocationAvailability) { callback.onLocationAvailability(availability.isLocationAvailable) }
        }
        callbackMap[callback] = playCallback
        fusedClient.requestLocationUpdates(playRequest, playCallback, looper)
    }

    override fun removeLocationUpdates(callback: TraceletLocationCallback) {
        val playCallback = callbackMap.remove(callback)
        if (playCallback != null) fusedClient.removeLocationUpdates(playCallback)
    }

    @SuppressLint("MissingPermission")
    override fun getCurrentLocation(priority: Int, cancellationToken: TraceletCancellationToken?, onSuccess: (Location?) -> Unit) {
        val cts = CancellationTokenSource()
        cancellationToken?.onCanceled { cts.cancel() }
        fusedClient.getCurrentLocation(priority, cts.token)
            .addOnSuccessListener { onSuccess(it) }
            .addOnFailureListener { onSuccess(null) }
    }

    @SuppressLint("MissingPermission")
    override fun getLastLocation(onSuccess: (Location?) -> Unit, onFailure: (Exception) -> Unit) {
        fusedClient.lastLocation
            .addOnSuccessListener { onSuccess(it) }
            .addOnFailureListener { onFailure(it) }
    }
}

class PlayGeofencingClient(context: Context) : TraceletGeofencingClient {
    private val client: GeofencingClient = LocationServices.getGeofencingClient(context)

    @SuppressLint("MissingPermission")
    override fun addGeofences(request: TraceletGeofencingRequest, pendingIntent: PendingIntent, onSuccess: () -> Unit, onFailure: (Exception) -> Unit) {
        val playGeofences = request.geofences.map {
            Geofence.Builder()
                .setRequestId(it.requestId)
                .setCircularRegion(it.latitude, it.longitude, it.radiusMeters)
                .setExpirationDuration(it.expirationTime)
                .setTransitionTypes(it.transitionTypes)
                .setLoiteringDelay(it.loiteringDelayMs)
                .build()
        }
        val playRequest = GeofencingRequest.Builder().setInitialTrigger(request.initialTrigger).addGeofences(playGeofences).build()
        client.addGeofences(playRequest, pendingIntent).addOnSuccessListener { onSuccess() }.addOnFailureListener { onFailure(it) }
    }

    override fun removeGeofences(pendingIntent: PendingIntent, onSuccess: () -> Unit, onFailure: (Exception) -> Unit) {
        client.removeGeofences(pendingIntent).addOnSuccessListener { onSuccess() }.addOnFailureListener { onFailure(it) }
    }

    override fun removeGeofences(requestIds: List<String>, onSuccess: () -> Unit, onFailure: (Exception) -> Unit) {
        client.removeGeofences(requestIds).addOnSuccessListener { onSuccess() }.addOnFailureListener { onFailure(it) }
    }
}

class PlayActivityRecognitionClient(context: Context) : TraceletActivityRecognitionClient {
    private val client: ActivityRecognitionClient = ActivityRecognition.getClient(context)

    @SuppressLint("MissingPermission")
    override fun requestActivityUpdates(detectionIntervalMillis: Long, callbackIntent: PendingIntent, onSuccess: () -> Unit, onFailure: (Exception) -> Unit) {
        client.requestActivityUpdates(detectionIntervalMillis, callbackIntent).addOnSuccessListener { onSuccess() }.addOnFailureListener { onFailure(it) }
    }

    @SuppressLint("MissingPermission")
    override fun removeActivityUpdates(callbackIntent: PendingIntent, onSuccess: () -> Unit, onFailure: (Exception) -> Unit) {
        client.removeActivityUpdates(callbackIntent).addOnSuccessListener { onSuccess() }.addOnFailureListener { onFailure(it) }
    }

    @SuppressLint("MissingPermission")
    override fun requestActivityTransitionUpdates(request: TraceletActivityTransitionRequest, pendingIntent: PendingIntent, onSuccess: () -> Unit, onFailure: (Exception) -> Unit) {
        val playTransitions = request.transitions.map { ActivityTransition.Builder().setActivityType(it.activityType).setActivityTransition(it.transitionType).build() }
        val playRequest = ActivityTransitionRequest(playTransitions)
        client.requestActivityTransitionUpdates(playRequest, pendingIntent).addOnSuccessListener { onSuccess() }.addOnFailureListener { onFailure(it) }
    }

    @SuppressLint("MissingPermission")
    override fun removeActivityTransitionUpdates(pendingIntent: PendingIntent, onSuccess: () -> Unit, onFailure: (Exception) -> Unit) {
        client.removeActivityTransitionUpdates(pendingIntent).addOnSuccessListener { onSuccess() }.addOnFailureListener { onFailure(it) }
    }
}

class PlayEventExtractor : TraceletEventExtractor {
    override fun extractGeofencingEvent(intent: Intent): TraceletGeofencingEvent? {
        val event = GeofencingEvent.fromIntent(intent) ?: return null
        return TraceletGeofencingEvent(
            hasError = event.hasError(),
            errorCode = event.errorCode,
            geofenceTransition = event.geofenceTransition,
            triggeringGeofences = event.triggeringGeofences?.map { TraceletGeofence(it.requestId, 0.0, 0.0, 0f, 0, 0, 0) },
            triggeringLocation = event.triggeringLocation
        )
    }

    override fun extractActivityRecognitionResult(intent: Intent): TraceletActivityRecognitionResult? {
        if (!ActivityRecognitionResult.hasResult(intent)) return null
        val result = ActivityRecognitionResult.extractResult(intent) ?: return null
        return TraceletActivityRecognitionResult(
            probableActivities = result.probableActivities.map { TraceletDetectedActivity(it.type, it.confidence) },
            mostProbableActivity = TraceletDetectedActivity(result.mostProbableActivity.type, result.mostProbableActivity.confidence)
        )
    }

    override fun extractActivityTransitionResult(intent: Intent): TraceletActivityTransitionResult? {
        if (!ActivityTransitionResult.hasResult(intent)) return null
        val result = ActivityTransitionResult.extractResult(intent) ?: return null
        return TraceletActivityTransitionResult(
            transitionEvents = result.transitionEvents.map { TraceletActivityTransitionEvent(it.activityType, it.transitionType, it.elapsedRealTimeNanos) }
        )
    }
}

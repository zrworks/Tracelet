package com.ikolvi.tracelet.reactnative

import android.Manifest
import android.os.Build
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import com.facebook.react.bridge.*
import com.facebook.react.modules.core.PermissionAwareActivity
import com.facebook.react.modules.core.PermissionListener
import com.ikolvi.tracelet.sdk.model.AuthorizationStatus

// We can implement PermissionListener in TraceletModule!

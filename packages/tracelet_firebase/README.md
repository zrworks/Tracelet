# Tracelet Firebase Adapter

The official Firebase adapter for [Tracelet](https://pub.dev/packages/tracelet).

This adapter seamlessly connects Tracelet's battery-efficient native HTTP sync engine to the Firebase Realtime Database (RTDB) via its REST API. By pushing locations directly to the RTDB, you achieve 100% serverless, zero-cost (free tier) background location tracking without the need to deploy Cloud Functions.

## Features
* **Zero Cloud Functions**: Syncs directly to RTDB via Firebase's REST API.
* **Auto Token Refresh**: Automatically detects 401 errors in the background and refreshes the Firebase Auth ID token natively.
* **Batch Syncing**: Compatible with Tracelet's batch engine out of the box.

## Getting Started

1. Set up Firebase in your Flutter app using `firebase_core` and `firebase_auth`.
2. Initialize Tracelet using `TraceletFirebase`.

```dart
import 'package:tracelet_firebase/tracelet_firebase.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // 1. Configure the auto-token refresher
  await TraceletFirebase.configureTokenRefresh();

  // 2. Build the HTTP Config pointing to your RTDB
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    final httpConfig = await TraceletFirebase.buildHttpConfig(
      databaseUrl: 'https://your-project-default-rtdb.firebaseio.com',
      path: 'locations/${user.uid}', // Secure this path in your RTDB rules
    );

    // 3. Start Tracelet
    await Tracelet.ready(Config(
      http: httpConfig,
    ));
  }
}
```

## Customizing the Payload
If you want to inject custom data (like an `order_id` or `trip_id`) into every location point dynamically, you can use the `Tracelet.setRouteContext()` API in Dart. For example:

```dart
await Tracelet.setRouteContext(RouteContext(
  taskId: 'order_123',
  custom: {'trip_id': 'trip_456'},
));
```

The route context data travels with the location row through the sync queue and will be included in the Firebase RTDB payload. Do not reshape the core JSON manually in Dart, as this drains the battery.

## Security Rules
Make sure to secure your RTDB to only allow authenticated users to write to their own location path:

```json
{
  "rules": {
    "locations": {
      "$uid": {
        ".read": "auth != null && auth.uid === $uid",
        ".write": "auth != null && auth.uid === $uid"
      }
    }
  }
}
```

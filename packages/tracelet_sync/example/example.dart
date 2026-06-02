import 'package:tracelet/tracelet.dart';
import 'package:tracelet_sync/tracelet_sync.dart';

void main() async {
  // Tracelet Sync plugin automatically connects to Tracelet Core
  // No configuration is required.
  // 
  // Make sure you have configured Tracelet Core correctly:
  await Tracelet.init(
    config: const EngineConfig(
      location: LocationConfig(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
      http: HttpConfig(
        endpoint: 'https://api.example.com/locations',
        headers: {'Authorization': 'Bearer YOUR_TOKEN'},
        batchSize: 50,
      ),
    ),
  );

  // Start tracking
  await Tracelet.startTracking();
}

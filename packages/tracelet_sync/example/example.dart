import 'package:tracelet/tracelet.dart';
import 'package:tracelet_sync/tracelet_sync.dart'; // ignore: unused_import

void main() async {
  // Tracelet Sync plugin automatically connects to Tracelet Core
  // No configuration is required.
  //
  // Make sure you have configured Tracelet Core correctly:
  await Tracelet.ready(
    const Config(
      http: HttpConfig(
        url: 'https://api.example.com/locations',
        headers: {'Authorization': 'Bearer YOUR_TOKEN'},
        maxBatchSize: 50,
      ),
    ),
  );

  // Start tracking
  await Tracelet.start();
}

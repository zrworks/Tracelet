import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tracelet/tracelet.dart';

/// Issue #147: the Pigeon `TlState` FFI struct was defined without the `config`
/// field, so `State.config` returned from `ready()` / `getState()` was
/// permanently `null`, breaking features that validate active runtime
/// parameters. The Dart layer now backfills the active config into the returned
/// state. This test asserts `state.config` is populated and reflects the config
/// that was passed to `ready()`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ready()/getState() populate state.config (#147)', (
    tester,
  ) async {
    const url = 'https://example.com/issue-147';
    final readyState = await Tracelet.ready(
      const Config(http: HttpConfig(url: url, maxBatchSize: 77)),
    );

    expect(
      readyState.config,
      isNotNull,
      reason: '#147: state.config must not be null after ready()',
    );
    expect(readyState.config!.http.url, url);
    expect(readyState.config!.http.maxBatchSize, 77);

    // getState() must carry the active config too.
    final fetched = await Tracelet.getState();
    expect(
      fetched.config,
      isNotNull,
      reason: '#147: state.config must not be null from getState()',
    );
    expect(fetched.config!.http.url, url);

    await Tracelet.stop();
  });
}

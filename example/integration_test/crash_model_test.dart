import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// On-device verification of the crash-ML chain (#183): AES-256-GCM decrypt of an
/// encrypted forest blob + random-forest tree-walk inference, running through the
/// real Rust core (`CrashModel`) on the device.
///
/// Uses a fixed encrypted blob of a tiny synthetic forest (generated offline) and
/// a deterministic 32-byte key, decrypted natively via the
/// `com.tracelet/debug` → `debugCrashModelPredict` hook (Android example app).
///
/// Run: `flutter test integration_test/crash_model_test.dart -d <android>`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const debug = MethodChannel('com.tracelet/debug');

  // Synthetic 2-tree forest over feature x0, AES-256-GCM encrypted with the key
  // below ([0x01][nonce:12][ciphertext]). x0=3.0 → tree A(>2)=0.9, B(<=5)=0.4 →
  // average 0.65.
  const blobB64 =
      'AQcHBwcHBwcHBwcHB3RIwDkOe6KGo+4xuqAK1uORftBfqNXidZ/ILZ93/Ag7fHTdXrAd2LIgitOYp2T7HJsTyGuzxGB/6JqEwFeY2MBphd0ApegH8xH3F2KT62K/t1A9TNKMcRS0CEluRAcqueC/o43zeTq/ElDoBPOonz3PQ+tYci9nCZOaluLVA6RferDoL92R0YMHFF51sbvz4FEmaKrgTustzGDflhQ64IazGLbaKZ1VWn/2EQIy94dNlTDqmLJgVY8drnKwlGPUl0ppPdh6F5nMmnuSd2sCoBLjZbnzomTQ5kVJgMgwkTaFLGGxozjkDBw9K4f8qIjLrKPQd7R9z7cJxfZr2jots2EI8dS9kA12rU8bXVQO1He9A6LTYE1aR87N74DCw085yFYdopZI6k9Mr8Vtza34PyWKM4vF/foqPEhsBhjXOWn6vDb4o+IggcMYZzIvJBJusRXWwoapIwPP5wTZXx0VsHTxDx/KMTn1sLt5oAVZMAM2ZnvJxg1nIDay1g==';
  const keyB64 = 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=';

  test('#183: decrypts + scores the crash model on-device', () async {
    final res = await debug.invokeMapMethod<String, Object?>(
      'debugCrashModelPredict',
      {
        'blob': blobB64,
        'key': keyB64,
        'features': <double>[3],
      },
    );
    expect(res, isNotNull);
    final r = res!;
    expect(r['treeCount'], 2);
    expect(r['proba']! as double, closeTo(0.65, 1e-6));
  });

  test(
    '#183 Phase 2b: loader downloads + verifies sha + decrypts on-device',
    () async {
      // Serve the encrypted blob over loopback; the native loader downloads it,
      // verifies the SHA-256, decrypts (AES-GCM), caches, and scores.
      final blob = base64.decode(blobB64);
      const sha256Hex =
          '12155f25fc8b5b668c04f8c0deb30501c84985d0982d55c74f6a8b20dca27cd3';
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        req.response.add(blob);
        await req.response.close();
      });
      addTearDown(() => server.close(force: true));

      final res = await debug
          .invokeMapMethod<String, Object?>('debugCrashModelLoad', {
            'url': 'http://127.0.0.1:${server.port}/model.enc',
            'sha256': sha256Hex,
            'key': keyB64,
          });
      expect(res, isNotNull);
      final r = res!;
      expect(r['treeCount'], 2);
      expect(r['proba']! as double, closeTo(0.65, 1e-6));
    },
  );

  test('#183: wrong key fails to decrypt (PlatformException)', () async {
    // All-zero key ≠ the real key → AES-GCM auth fails.
    const wrongKey = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';
    await expectLater(
      debug.invokeMapMethod<String, Object?>('debugCrashModelPredict', {
        'blob': blobB64,
        'key': wrongKey,
        'features': <double>[3],
      }),
      throwsA(isA<PlatformException>()),
    );
  });
}

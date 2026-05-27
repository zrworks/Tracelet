# Device Attestation

**Enterprise Feature** — Verify device and app integrity using platform attestation APIs.

Device attestation proves that location data originates from a genuine,
untampered device running an authentic copy of your application. Tracelet
integrates with Google Play Integrity (Android) and App Attest (iOS) to
generate cryptographic attestation tokens that your server can verify.

## Use Cases

| Scenario | Benefit |
| --- | --- |
| Fleet management | Ensure location data comes from company devices |
| Insurance telematics | Prevent claims fraud via spoofed location apps |
| Compliance auditing | Prove data origin for regulatory submissions |
| Anti-fraud | Detect rooted/jailbroken devices or modified APKs |
| High-value asset tracking | Verify device authenticity for chain of custody |

## Quick Start

```dart
import 'package:tracelet/tracelet.dart' as tl;

// 1. Enable attestation in config
final state = await tl.Tracelet.ready(tl.Config.balanced().copyWith(
  attestation: tl.AttestationConfig(
    enabled: true,
    refreshInterval: 3600,  // refresh every hour
  ),
));

// 2. Request an attestation token
final token = await tl.Tracelet.getAttestationToken();
if (token != null) {
  print('Provider: ${token.provider}');    // "play_integrity" or "app_attest"
  print('Token: ${token.token}');          // Platform-specific token string
  print('Generated: ${token.timestamp}');  // When token was created
}
```

## Configuration

Add `AttestationConfig` to your `Config`:

```dart
Config(
  attestation: AttestationConfig(
    // Enable device attestation (default: false)
    enabled: true,

    // Token auto-refresh interval in seconds (default: 3600)
    // Minimum: 60 seconds
    // Free tier rate limit: ~10,000 requests/day
    refreshInterval: 3600,

    // Optional server-side verification URL (default: null)
    // If set, tokens are automatically sent for server verification.
    // Must be HTTPS.
    verificationUrl: 'https://your-server.com/verify-attestation',
  ),
)
```

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `enabled` | `bool` | `false` | Enable device attestation |
| `refreshInterval` | `int` | `3600` | Auto-refresh interval in seconds (min: 60) |
| `verificationUrl` | `String?` | `null` | HTTPS URL for server-side token verification |

---

## API Reference

### `Tracelet.getAttestationToken()`

Request an attestation token from the platform. Returns a cached token
if one is still fresh (within 5 minutes), otherwise generates a new one.

```dart
final token = await Tracelet.getAttestationToken();
if (token != null) {
  // Send token to your server for verification
  await sendToServer(token.token, token.provider);
}
```

| Returns | Description |
| --- | --- |
| `Future<AttestationToken?>` | Token object, or `null` on unsupported platforms (web) |

### AttestationToken

| Property | Type | Description |
| --- | --- | --- |
| `token` | `String` | Platform-specific attestation token |
| `timestamp` | `DateTime` | When the token was generated |
| `provider` | `String` | Platform provider identifier |
| `verified` | `bool?` | Server verification result (`null` if not verified) |

**Provider values:**

| Value | Platform | API |
| --- | --- | --- |
| `play_integrity` | Android | Google Play Integrity API |
| `app_attest` | iOS 14+ | DCAppAttestService |
| `device_check` | iOS (fallback) | DeviceCheck framework |

---

## Platform Implementation

### Android — Google Play Integrity API

**Optional Dependency:** To enable Play Integrity on Android, you must explicitly add the dependency to your **app-level** `build.gradle.kts`:

```kotlin
// android/app/build.gradle.kts
dependencies {
    implementation("com.google.android.play:integrity:1.6.0")
}
```

| Component | Detail |
| --- | --- |
| API | Play Integrity API (`com.google.android.play:integrity:1.6.0`) |
| Nonce | SHA-256 of device fingerprint + timestamp + random bytes |
| Token format | JWT (JSON Web Token) |
| Cache duration | 5 minutes |
| Rate limit | ~10,000 requests/day (free tier) |

**How it works:**

```
┌───────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Tracelet SDK  │────▶│  Play Integrity  │────▶│  Google servers  │
│  (on device)   │     │  API             │     │  (attestation)   │
└───────────────┘     └──────────────────┘     └─────────────────┘
       │                                               │
       │  1. Generate nonce (SHA-256)                   │
       │  2. requestIntegrityToken(nonce)    ──────────▶│
       │                                     ◀──────────│
       │  3. Receive JWT verdict token                  │
       │  4. Cache token with timestamp                 │
       ▼                                               
  Return to Dart
```

**Verdict token contents** (decoded server-side):

- `requestDetails` — nonce, timestamp, package name
- `appIntegrity` — APK certificate hash, version code
- `deviceIntegrity` — device recognition verdict
- `accountDetails` — Play licensing status

### iOS — App Attest (DCAppAttestService)

| Component | Detail |
| --- | --- |
| API | DCAppAttestService (iOS 14+) |
| Fallback | DeviceCheck framework |
| Token format | CBOR attestation object (base64-encoded) |
| Cache duration | 5 minutes |
| Hardware backing | Secure Enclave |

**How it works:**

```
┌───────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Tracelet SDK  │────▶│  DCAppAttest     │────▶│  Apple servers   │
│  (on device)   │     │  Service         │     │  (attestation)   │
└───────────────┘     └──────────────────┘     └─────────────────┘
       │                                               │
       │  1. generateKey()                              │
       │  2. Generate challenge (32 random bytes)       │
       │  3. SHA-256 hash of challenge                  │
       │  4. attestKey(keyId, clientDataHash)  ────────▶│
       │                                     ◀──────────│
       │  5. Receive CBOR attestation                   │
       │  6. Base64-encode and cache                    │
       ▼                                               
  Return to Dart
```

**Attestation object contents:**

- `attStmt` — attestation statement (X.509 certificate chain)
- `authData` — authenticator data (key identifier, flags)

> **Fallback:** On devices where App Attest is unavailable, Tracelet
> falls back to the DeviceCheck framework. The `provider` field will be
> `"device_check"` instead of `"app_attest"`.

---

## Server-Side Verification

Attestation tokens must be verified server-side to be meaningful.
The token alone proves nothing — your server must validate it against
the platform's verification API.

### Android Verification

```
POST https://playintegrity.googleapis.com/v1/{packageName}:decodeIntegrityToken
Authorization: Bearer <service-account-token>
Content-Type: application/json

{
  "integrity_token": "<token from AttestationToken.token>"
}
```

### iOS Verification

1. Decode the base64 CBOR attestation object
2. Verify the X.509 certificate chain against Apple's App Attest root CA
3. Validate the `authData` fields (RP ID hash, counter, flags)
4. Check the `credCert` public key matches the key ID

### Using verificationUrl

If you configure `verificationUrl`, Tracelet automatically sends tokens
to your server:

```dart
AttestationConfig(
  enabled: true,
  verificationUrl: 'https://api.example.com/verify',
)
```

Your endpoint receives a POST with the token payload. Return a JSON
response with `{"verified": true}` or `{"verified": false}` to update
the `AttestationToken.verified` field.

---

## Auto-Refresh

When `refreshInterval` is set, Tracelet automatically refreshes the
attestation token in the background:

```dart
AttestationConfig(
  enabled: true,
  refreshInterval: 1800,  // refresh every 30 minutes
)
```

The refresh uses a platform-native scheduler:
- **Android:** `ScheduledExecutorService`
- **iOS:** `Timer`

The minimum interval is 60 seconds. Values below 60 are clamped to 60.

---

## Rate Limits

| Platform | Free Tier | Paid Tier |
| --- | --- | --- |
| Android (Play Integrity) | ~10,000 requests/day | Unlimited (Play Console billing) |
| iOS (App Attest) | No published limit | — |

> **Recommendation:** Set `refreshInterval` to at least 3600 (1 hour) for
> production apps to stay well within rate limits.

---

## Best Practices

1. **Always verify server-side** — Client-side tokens are meaningless
   without server verification. Set up a verification endpoint.

2. **Use reasonable refresh intervals** — 3600 seconds (1 hour) is
   sufficient for most use cases. More frequent refreshes waste API quota.

3. **Handle null gracefully** — `getAttestationToken()` returns `null`
   on unsupported platforms (web) or when attestation is disabled.

4. **Combine with audit trail** — Attestation proves device authenticity;
   the audit trail proves data integrity. Together they provide
   end-to-end trust.

5. **Monitor provider field** — On iOS, check if the provider is
   `"app_attest"` or `"device_check"` — the fallback provides weaker
   guarantees.

---

## Related Guides

- [Database Encryption](DATABASE-ENCRYPTION.md) — At-rest data encryption
- [Audit Trail](AUDIT-TRAIL.md) — Tamper-proof hash chain
- [Mock Detection](MOCK-DETECTION.md) — Detect spoofed locations
- [Compliance Report](COMPLIANCE-REPORT.md) — Auto-generated compliance reports
- [API Reference](API.md) — All methods and return types

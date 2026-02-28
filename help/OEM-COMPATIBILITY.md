# OEM Compatibility Guide

Android manufacturers like Huawei, Xiaomi, OnePlus, Samsung, Oppo, and Vivo
ship custom power management that aggressively kills background apps — even
properly-configured foreground services with `START_STICKY` and `WAKE_LOCK`.

Tracelet includes built-in mitigations and a **Settings Health API** that lets
you detect aggressive OEMs and guide users through the correct settings.

> **iOS and Web:** These platforms do not have OEM-specific power management
> issues. The Settings Health API returns `isAggressiveOem: false` on both.

---

## OEM Aggression Ratings

Ratings sourced from [dontkillmyapp.com](https://dontkillmyapp.com/):

| Manufacturer | ROM | Rating | Primary Kill Mechanism |
|---|---|---|---|
| **Huawei** | EMUI / HarmonyOS | 5/5 | PowerGenie / HwPFWService |
| **Xiaomi** | MIUI / HyperOS | 5/5 | Autostart / MIUI Optimization |
| **OnePlus** | OxygenOS | 5/5 | Advanced / Deep Optimization |
| **Samsung** | One UI | 4/5 | Adaptive Battery / App Sleep |
| **Oppo** | ColorOS | 3/5 | Startup Manager |
| **Vivo** | FuntouchOS | 3/5 | Background Activity Manager |

---

## Built-in Mitigations

Tracelet applies these automatically — no configuration needed:

### 1. OEM-Safe Wakelocks (Huawei)

Huawei's PowerGenie inspects wakelock tags and kills processes holding
"unknown" wakelocks. Tracelet uses the tag `LocationManagerService` on Huawei
devices, which is whitelisted by PowerGenie as a system-level location service.
On all other manufacturers, the standard tag `com.tracelet:location` is used.

### 2. Boot Receiver Wakelock

On device reboot, aggressive OEMs may kill processes between
`BOOT_COMPLETED` broadcast receipt and foreground service startup. Tracelet
acquires a temporary 60-second wakelock during boot processing to keep the
process alive until the foreground service is established.

### 3. Foreground Service with TYPE_LOCATION

Tracelet declares `FOREGROUND_SERVICE_LOCATION` and starts the service with
`ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION`, giving it the highest
background priority on all Android versions.

### 4. START_STICKY Service

The location service returns `START_STICKY` from `onStartCommand`, telling
Android to recreate the service if it's killed due to memory pressure.

### 5. ProGuard / R8 Consumer Rules

Tracelet ships consumer ProGuard rules that prevent R8 from stripping critical
classes (services, receivers, Room entities) during release builds. These
rules are applied automatically to host apps — no manual configuration needed.

---

## Settings Health API

The Settings Health API lets you build a "Device Health" UI that checks the
device's OEM compatibility status and guides users through manufacturer-specific
settings.

### Check Device Health

```dart
final health = await Tracelet.getSettingsHealth();

print('Manufacturer: ${health['manufacturer']}');
print('Model: ${health['model']}');
print('Aggressive OEM: ${health['isAggressiveOem']}');
print('Aggression Rating: ${health['aggressionRating']}/5');
print('Battery Opt Exempt: ${health['isIgnoringBatteryOptimizations']}');
print('Autostart Available: ${health['autostartAvailable']}');
```

### Response Format

| Key | Type | Description |
|---|---|---|
| `manufacturer` | `String` | Device manufacturer (e.g. `"Huawei"`) |
| `model` | `String` | Device model (e.g. `"P40 Pro"`) |
| `isAggressiveOem` | `bool` | `true` if OEM is known to kill background apps |
| `aggressionRating` | `int` | 0–5 severity rating per dontkillmyapp.com |
| `isIgnoringBatteryOptimizations` | `bool` | Whether app is exempt from Doze |
| `autostartAvailable` | `bool` | Whether Xiaomi/MIUI autostart screen exists |
| `oemSettingsScreens` | `List<Map>` | Available OEM-specific settings screens |

Each entry in `oemSettingsScreens` has:

| Key | Type | Description |
|---|---|---|
| `label` | `String` | Unique identifier (e.g. `"Xiaomi Autostart"`) |
| `description` | `String` | User-friendly explanation |

### Open OEM Settings

```dart
final health = await Tracelet.getSettingsHealth();
final screens = health['oemSettingsScreens'] as List? ?? [];

for (final screen in screens) {
  final label = (screen as Map)['label'] as String;
  final description = screen['description'] as String;
  print('$label: $description');

  // Open the settings screen
  final opened = await Tracelet.openOemSettings(label);
  if (!opened) {
    print('Screen not available on this device.');
  }
}
```

---

## Available OEM Settings Screens

Tracelet validates each intent at runtime using `PackageManager.resolveActivity()`
— only screens that exist on the specific device are returned.

### Xiaomi (MIUI / HyperOS)

| Label | Description | What it does |
|---|---|---|
| `Xiaomi Autostart` | Enable autostart to allow background location tracking | Opens Autostart Management Activity. Enable your app to survive reboots and receive `BOOT_COMPLETED`. |
| `Xiaomi Battery Saver` | Disable battery saver restrictions for this app | Opens MIUI/HyperOS battery saver settings. Set your app to "No restrictions". |

### Huawei (EMUI / HarmonyOS)

| Label | Description | What it does |
|---|---|---|
| `Huawei App Launch` | Set app launch to Manual and enable all switches | Opens App Launch settings. Set to **Manage Manually** and enable Auto-launch, Secondary launch, and Run in background. |
| `Huawei Protected Apps` | Add this app to protected apps list | Opens Protected Apps list. Enable your app to prevent PowerGenie from killing it. |

### OnePlus (OxygenOS)

| Label | Description | What it does |
|---|---|---|
| `OnePlus Battery Optimization` | Disable battery optimization for this app | Opens Battery Optimization. Select your app and choose **Don't optimize**. Disable **Deep Optimization** and **Sleep Standby Optimization** separately. |

### Oppo (ColorOS)

| Label | Description | What it does |
|---|---|---|
| `Oppo Startup Manager` | Allow this app to run at startup | Opens ColorOS Startup Manager or Safe Center. Enable auto-start for your app. |

### Vivo (FuntouchOS / OriginOS)

| Label | Description | What it does |
|---|---|---|
| `Vivo Background Activity` | Allow unrestricted background activity | Opens Background Activity Manager or iQOO Secure BgStartUp Manager. |

### Samsung (One UI)

| Label | Description | What it does |
|---|---|---|
| `Samsung Battery Settings` | Disable Adaptive Battery for this app | Opens Samsung Battery Settings. Find your app under "Sleeping apps" or "Deep sleeping apps" and remove it. |

---

## Recommended User Onboarding Flow

### Step 1: Check Battery Optimization

```dart
final isExempt = await Tracelet.isIgnoringBatteryOptimizations();
if (!isExempt) {
  // Show dialog explaining why battery optimization exemption is needed
  await Tracelet.openBatterySettings();
}
```

### Step 2: Check OEM-Specific Settings

```dart
final health = await Tracelet.getSettingsHealth();

if (health['isAggressiveOem'] == true) {
  final rating = health['aggressionRating'] as int;
  final screens = health['oemSettingsScreens'] as List? ?? [];

  // Show a "Device Health" card with manufacturer-specific guidance
  // Higher rating = more important to fix
  for (final screen in screens) {
    final label = (screen as Map)['label'] as String;
    final description = screen['description'] as String;

    // Show each setting with an "Open" button
    // When tapped:
    await Tracelet.openOemSettings(label);
  }
}
```

### Step 3: Full Health Check Example

```dart
Future<void> showDeviceHealth() async {
  final health = await Tracelet.getSettingsHealth();
  final issues = <String>[];

  // Check battery optimization
  if (health['isIgnoringBatteryOptimizations'] != true) {
    issues.add('Battery optimization is not disabled');
  }

  // Check autostart (Xiaomi)
  if (health['autostartAvailable'] == true) {
    issues.add('Xiaomi Autostart may need to be enabled');
  }

  // Check OEM settings
  final screens = health['oemSettingsScreens'] as List? ?? [];
  if (screens.isNotEmpty) {
    issues.add('${screens.length} OEM setting(s) may need adjustment');
  }

  if (issues.isEmpty) {
    print('✓ Device is properly configured for background tracking');
  } else {
    print('⚠ ${issues.length} issue(s) found:');
    for (final issue in issues) {
      print('  • $issue');
    }
  }
}
```

---

## Manufacturer-Specific Notes

### Huawei — PowerGenie

PowerGenie is the most aggressive background killer in the Android ecosystem.
On EMUI 9+, it monitors all running processes and terminates anything not
explicitly whitelisted. Tracelet's wakelock tag hack (`LocationManagerService`)
provides partial protection, but **manual user configuration is still
required** on many devices:

1. Go to **Settings → Battery → App Launch**
2. Find your app and set to **Manage Manually**
3. Enable all three toggles: Auto-launch, Secondary launch, Run in background

On some EMUI versions, background services are hard-killed after 60 minutes
regardless of configuration. In enterprise deployments with ADB access, the
only definitive fix is removing PowerGenie:

```
adb shell pm uninstall -k --user 0 com.huawei.powergenie
```

### Xiaomi — MIUI Autostart

MIUI prevents apps from auto-starting after reboot unless the **Autostart**
permission is manually granted. Tracelet detects whether this screen is
available via `autostartAvailable` in the health check.

Additionally, users should **lock the app** in the Recent Apps switcher by
dragging the app card downward until a padlock icon appears. This prevents MIUI
from killing the app during "Clear All" operations.

### OnePlus — Deep Optimization

OxygenOS has two critical toggles:
- **Deep Optimization**: Ignores wakelocks and suspends network in background
- **Sleep Standby Optimization**: AI-driven, disables network during sleep

Both must be disabled for reliable background tracking. Note that OnePlus
devices **may reset these settings after firmware updates**.

### Samsung — Adaptive Battery

Samsung's One UI is less aggressive than Chinese OEMs (4/5 rating) but still
uses Adaptive Battery and App Sleep lists. Ensure your app is not in:
- **Sleeping apps** list
- **Deep sleeping apps** list
- **Never sleeping apps** list (add your app here)

---

## Troubleshooting

### Background tracking stops after screen lock

1. Check `isIgnoringBatteryOptimizations` — must be `true`
2. Check `isAggressiveOem` — if `true`, open all available OEM settings
3. On Xiaomi: enable Autostart and lock the app in Recents
4. On Huawei: set App Launch to Manual with all toggles enabled
5. On OnePlus: disable Deep Optimization and Sleep Standby Optimization

### Tracking doesn't resume after reboot

1. Ensure `startOnBoot: true` in `AppConfig`
2. On Xiaomi: Autostart permission must be enabled
3. On Oppo/Vivo: Startup Manager must allow the app
4. Check that the notification permission is granted (Android 13+)

### Tracking stops after a few hours

1. This is typically Huawei PowerGenie — follow the Huawei steps above
2. On Samsung: remove app from Sleeping/Deep sleeping apps lists
3. Ensure foreground notification is visible (not hidden by DND)

---

## Further Reading

- [Don't Kill My App](https://dontkillmyapp.com/) — crowdsourced OEM
  background-killing data
- [Background Tracking Guide](BACKGROUND-TRACKING.md) — Tracelet's
  background tracking configuration
- [Permissions Guide](PERMISSIONS.md) — permission flow and best practices
- [Configuration Guide](CONFIGURATION.md) — full configuration reference

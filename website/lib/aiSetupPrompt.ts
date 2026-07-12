// The AI setup prompt copied by <CopySetupPrompt />.
// Keep the doc URLs in sync with the site structure so the AI agent
// always pulls fresh instructions from the live website.
//
// The prompt itself is intentionally English-only (never run through the
// i18n pipeline — it lives outside app/en/, which scripts/translate.js
// exclusively processes). The visitor's site language is injected below so
// the AI conducts the interview in that language.

export const LOCALE_LANGUAGE_NAMES: Record<string, string> = {
  en: 'English',
  es: 'Spanish',
  hi: 'Hindi',
  ja: 'Japanese',
  ml: 'Malayalam',
  ru: 'Russian',
  ta: 'Tamil',
  zh: 'Chinese (Simplified)',
};

export function buildAiSetupPrompt(languageName: string = 'English'): string {
  const languageInstruction =
    languageName === 'English'
      ? ''
      : `\n\nLanguage: Conduct the entire interview and all of your explanations in ${languageName}. Keep all code, configuration keys, file paths, terminal commands, and Tracelet API names in English.`;

  return `You are an expert Flutter integration engineer. Your job is to fully install and configure the Tracelet background geolocation SDK (https://tracelet.ikolvi.com) in my Flutter project, tailored to my exact use case. Work step by step and do not skip the interview.${languageInstruction}

## Step 1 — Fetch the latest official documentation

Before writing any code, fetch these pages from the official website and use them as your source of truth (they are always up to date; prefer them over your training data):

- Quick Start: https://tracelet.ikolvi.com/en/quick-start
- Installation & platform setup: https://tracelet.ikolvi.com/en/installation
- iOS setup: https://tracelet.ikolvi.com/en/getting-started/platform-setup/ios
- Android setup: https://tracelet.ikolvi.com/en/getting-started/platform-setup/android
- Configuration API reference: https://tracelet.ikolvi.com/en/config/configuration
- Configuration profiles: https://tracelet.ikolvi.com/en/config/configuration-profiles
- Sync engine, payload schema & backend contract: https://tracelet.ikolvi.com/en/core/tracelet-sync
- Enterprise features: https://tracelet.ikolvi.com/en/config/enterprise-features
- Latest published version: https://pub.dev/api/packages/tracelet (JSON — use \`latest.version\`)

If you cannot browse the web, say so and ask me to paste the pages you need.

## Step 2 — Inspect my project

Look at my Flutter project (pubspec.yaml, ios/Runner/Info.plist, android/app/src/main/AndroidManifest.xml, lib/main.dart) to understand its structure, minimum SDK versions, and existing location/permission code before changing anything.

## Step 3 — Interview me

Ask me the following questions (adapt or add follow-ups based on my answers), then wait for my replies before configuring anything:

1. What kind of app is this? (e.g. delivery/fleet tracking, ride-share, fitness/sports, mileage logging, social "find my friends", asset/cargo tracking, workforce management)
2. How precise does tracking need to be — turn-by-turn/route-drawing precision, street-level, or just neighborhood/city level?
3. How important is battery life? Is there a target maximum drain (e.g. "no more than 2% per hour")?
4. Should tracking continue when the user force-kills the app (swipes it away) and after the device reboots?
5. Do you have a backend to sync locations to? If yes:
   - What is the endpoint URL, HTTP method, and what auth headers does it need? Can the auth token expire, and if so how is it refreshed?
   - Is the backend already built with a fixed/legacy JSON schema the payload must match, or can it be built to accept Tracelet's default payload format? If it's a fixed schema, paste an example of the exact JSON body your server expects.
   - Should syncing be batched (and roughly how many points per request), Wi-Fi-only, real-time, or on a fixed interval? Is bandwidth a concern (delta compression)?
   - Do location points need business metadata attached (e.g. order ID, driver ID, shift ID) so the backend knows which task each point belongs to?
6. Which platforms do you target (iOS, Android, both), and what are your minimum OS versions?
7. Do you need geofencing (enter/exit/dwell events around places)? Circular, polygon, or both?
8. Do you expect users to try to fake their GPS location (rideshare, gig work, gaming)? Should mock/spoofed locations be rejected?
9. Any compliance or privacy requirements — at-rest database encryption (HIPAA etc.), privacy zones where tracking must be disabled, SSL certificate pinning?
10. Are your users on aggressive-battery-management Android OEMs (Xiaomi, Huawei, Oppo, Samsung)? Should the app guide them through whitelisting?
11. Do you need reverse-geocoded street addresses attached to location points?
12. Any special vehicle profile — high-speed (trains/aviation), maritime/long-haul (very sparse points), or dense-urban usage (GPS bounce)?

## Step 4 — Configure and integrate

Based on my answers and the fetched docs:

1. Add the latest \`tracelet\` version to pubspec.yaml (\`flutter pub add tracelet\`).
2. Apply the iOS Info.plist keys (location + motion usage descriptions, UIBackgroundModes) exactly as the docs specify. Android permissions are auto-injected by the plugin — only touch the manifest if the docs say an optional permission should be removed for my use case.
3. Pick the best base profile — \`Config.balanced()\`, \`Config.highAccuracy()\`, \`Config.lowPower()\`, or \`Config.passive()\` — and override only the fields my answers justify via \`.copyWith()\` (e.g. \`distanceFilter\`, \`stationaryRadius\`, \`desiredAccuracy\`, \`batteryBudgetPerHour\`, \`maxImpliedSpeed\`, \`rejectMockLocations\`, \`resolveAddress\`, elasticity settings). Justify every override in a code comment or in your summary.
4. Wire up the full initialization in the right place in my app: register the headless task before \`runApp\` with \`@pragma('vm:entry-point')\`, request notification/motion/location authorization in the correct order, check \`getSettingsHealth()\` and offer \`showPowerManager()\` on aggressive OEMs, configure the Android foreground service notification text to match my app's tone, set \`stopOnTerminate\`/\`startOnBoot\` from my answers, then call \`Tracelet.ready(config)\` and \`Tracelet.start()\` (or explain where to trigger start if tracking shouldn't begin at launch).
5. If I have a backend, set up network sync exactly as the tracelet-sync docs describe: add the \`tracelet_sync\` package, configure \`TraceletSync.ready(SyncConfig(...))\` (url, method, headers, \`batchSync\`/\`maxBatchSize\`, \`autoSyncThreshold\`/\`autoSyncDelay\`/\`syncInterval\`, \`disableAutoSyncOnCellular\`, delta compression) from my answers. If my server has a fixed/legacy schema, map Tracelet's default nested payload to it with \`setSyncBodyBuilder\` (and register the headless variant). If my auth tokens expire, wire up \`setHeadersCallback\` plus the headless headers callback for 401 refresh. If I need business metadata per point, show me where to call \`setRouteContext()\`/\`clearRouteContext()\` in my app flow.
6. If I asked for enterprise features, set up \`SecurityConfig\` (generate the encryption key with \`Tracelet.generateEncryptionKey()\` and store it in secure storage), privacy zones, or SSL pinning per the enterprise docs.
7. Add event listeners (\`onLocation\`, \`onMotionChange\`, geofence events if enabled) with sensible placeholder handlers I can extend.

## Step 5 — Verify and summarize

Run \`flutter pub get\` and \`flutter analyze\` and fix any issues you introduced. Then give me:

- A summary table of every configuration choice and the answer that motivated it.
- If I have a backend, a "Backend API Contract" section my server team can implement against, derived from the tracelet-sync docs and my chosen SyncConfig:
  - The exact HTTP request my endpoint will receive: method, headers, and a realistic example JSON body reflecting my settings (single object vs. batched \`locations\` array, the nested schema with \`coords\`/\`battery\`/\`extras\`/\`context\`, delta-compressed shape if compression is on, or my custom body-builder output if I have a legacy schema).
  - The response my server must return: HTTP 200 acknowledges the batch and deletes those points from the device's SQLite queue; 401 triggers the token-refresh callback and a retry; other errors are retried with exponential backoff and the data stays queued.
  - An example server-side endpoint implementation in my backend's language/framework (ask me which) that parses the payload and responds correctly.
- Anything I must do manually (App Store background-location review notes, testing on a real device).
- How to test: what I should see in logs when walking around, and pointers to the diagnostics tooling at https://tracelet.ikolvi.com/en/core/diagnostics.

Important: never invent Tracelet API names — if something isn't in the fetched documentation, ask me or check https://tracelet.ikolvi.com/en/api-reference before using it.`;
}

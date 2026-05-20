# Changelog

## 1.0.0

- **Initial release** of Tracelet Doctor.
- Drop-in diagnostic bottom sheet via `TraceletDoctor.show(context)`.
- Permission status card (location, motion activity, accuracy authorization).
- Tracking state card (enabled/disabled, mode, motion, odometer, scheduler).
- Battery & OEM card with aggression rating meter (Huawei, Xiaomi, Samsung detection).
- Sensor availability grid (accelerometer, gyroscope, magnetometer, significant-motion).
- Database & device card (pending queue count, mock detection, platform, OS version).
- Warning list with 12 `HealthWarning` types and human-readable descriptions.
- Copy-to-clipboard for full JSON diagnostic report.
- Re-run diagnostics without dismissing the sheet.
- Animated loading state and graceful error handling with retry.
- Dark glassmorphic theme with semantic status colors.

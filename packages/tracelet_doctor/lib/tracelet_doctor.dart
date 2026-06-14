/// Drop-in diagnostic overlay widget for Tracelet.
///
/// Visualizes permissions, battery health, OEM compatibility, sensor
/// availability, and tracking state with actionable fix suggestions.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:tracelet_doctor/tracelet_doctor.dart';
///
/// // Show as a modal bottom sheet:
/// TraceletDoctor.show(context);
/// ```
library tracelet_doctor;

export 'src/bug_report.dart';
export 'src/doctor_sheet.dart';
export 'src/doctor_theme.dart';

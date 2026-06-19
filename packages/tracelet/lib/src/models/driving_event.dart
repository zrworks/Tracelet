import 'package:meta/meta.dart';
import 'package:tracelet_platform_interface/tracelet_platform_interface.dart';

/// A driving-behavior event emitted by the telematics engine.
///
/// One of [kind]: `harsh_braking`, `harsh_acceleration`, `harsh_cornering`,
/// or `speeding`. Delivered via `Tracelet.onDrivingEvent`.
@immutable
class DrivingEvent {
  /// Creates a new [DrivingEvent].
  const DrivingEvent({
    required this.kind,
    required this.severity,
    required this.speed,
    required this.value,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  /// Creates a [DrivingEvent] from the Pigeon [TlDrivingEvent].
  factory DrivingEvent.fromTl(TlDrivingEvent e) => DrivingEvent(
    kind: e.kind,
    severity: e.severity,
    speed: e.speed,
    value: e.value,
    latitude: e.latitude,
    longitude: e.longitude,
    timestamp: DateTime.fromMillisecondsSinceEpoch(e.timestampMs),
  );

  /// Event kind: `harsh_braking` | `harsh_acceleration` | `harsh_cornering` | `speeding`.
  final String kind;

  /// Normalized 0–1 severity (how far past the threshold).
  final double severity;

  /// Speed at the event (m/s).
  final double speed;

  /// Measured magnitude: g for harsh events, km/h over the limit for speeding.
  final double value;

  /// Latitude at the event.
  final double latitude;

  /// Longitude at the event.
  final double longitude;

  /// When the event occurred.
  final DateTime timestamp;

  @override
  String toString() =>
      'DrivingEvent($kind, severity: ${severity.toStringAsFixed(2)}, '
      'value: ${value.toStringAsFixed(2)})';
}

/// A crash/fall impact event emitted by the impact detector.
///
/// [kind] is one of `potential_crash`, `crash`, `potential_fall`, `fall`. A
/// `potential_*` event carries a [confirmDeadline]; if the host does not call
/// `Tracelet.cancelImpact([id])` before then, the confirmed `crash`/`fall`
/// event fires. Delivered via `Tracelet.onImpact`.
@immutable
class ImpactEvent {
  /// Creates a new [ImpactEvent].
  const ImpactEvent({
    required this.kind,
    required this.id,
    required this.confidence,
    required this.peakG,
    required this.speedBefore,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.confirmDeadline,
  });

  /// Creates an [ImpactEvent] from the Pigeon [TlImpactEvent].
  factory ImpactEvent.fromTl(TlImpactEvent e) => ImpactEvent(
    kind: e.kind,
    id: e.id,
    confidence: e.confidence,
    peakG: e.peakG,
    speedBefore: e.speedBefore,
    latitude: e.latitude,
    longitude: e.longitude,
    timestamp: DateTime.fromMillisecondsSinceEpoch(e.timestampMs),
    confirmDeadline: DateTime.fromMillisecondsSinceEpoch(e.confirmDeadlineMs),
  );

  /// `potential_crash` | `crash` | `potential_fall` | `fall`.
  final String kind;

  /// Candidate id — pass to `cancelImpact`/`confirmImpact`.
  final int id;

  /// 0–1 detection confidence.
  final double confidence;

  /// Peak impact magnitude (g).
  final double peakG;

  /// Speed before impact (m/s).
  final double speedBefore;

  /// Latitude at impact.
  final double latitude;

  /// Longitude at impact.
  final double longitude;

  /// When the impact occurred.
  final DateTime timestamp;

  /// For `potential_*`: when it auto-confirms unless cancelled.
  final DateTime confirmDeadline;

  /// Whether this is a not-yet-confirmed candidate (`potential_*`).
  bool get isPotential => kind.startsWith('potential_');

  @override
  String toString() =>
      'ImpactEvent($kind, id: $id, peakG: ${peakG.toStringAsFixed(1)}, '
      'confidence: ${confidence.toStringAsFixed(2)})';
}

/// A fused transport-mode change emitted by the on-device classifier.
///
/// Delivered via `Tracelet.onModeChange`. [mode] is one of `still`, `walking`,
/// `running`, `cycling`, `vehicle`, or `unknown`.
@immutable
class ModeChangeEvent {
  /// Creates a new [ModeChangeEvent].
  const ModeChangeEvent({required this.mode, required this.confidence});

  /// Creates a [ModeChangeEvent] from the Pigeon [TlModeChangeEvent].
  factory ModeChangeEvent.fromTl(TlModeChangeEvent e) =>
      ModeChangeEvent(mode: e.mode, confidence: e.confidence);

  /// `still` | `walking` | `running` | `cycling` | `vehicle` | `unknown`.
  final String mode;

  /// 0–1 confidence of the classification.
  final double confidence;

  @override
  String toString() =>
      'ModeChangeEvent($mode, confidence: ${confidence.toStringAsFixed(2)})';
}

/// Lifecycle stage of the opt-in ML crash model (#183).
///
/// Lets the host app surface progress to the user while the model is being
/// prepared (e.g. show a "Downloading crash model…" spinner).
enum CrashModelStatus {
  /// Validating the license and unlocking the decryption key.
  unlocking,

  /// Downloading the encrypted model blob.
  downloading,

  /// Verifying and decrypting the downloaded blob.
  decrypting,

  /// Model is loaded and actively scoring impacts.
  ready,

  /// Preparation failed — see [CrashModelStatusEvent.detail] for the reason.
  failed,

  /// ML crash model is not enabled in the current configuration.
  disabled,

  /// An unrecognised status string was received.
  unknown,
}

/// A status update for the opt-in ML crash model lifecycle.
///
/// Delivered via `Tracelet.crashModelStatusStream`. Use it to drive UI such as
/// a download indicator before crash detection becomes active.
@immutable
class CrashModelStatusEvent {
  /// Creates a new [CrashModelStatusEvent].
  const CrashModelStatusEvent({required this.status, this.detail});

  /// Creates a [CrashModelStatusEvent] from the Pigeon [TlCrashModelStatusEvent].
  factory CrashModelStatusEvent.fromTl(TlCrashModelStatusEvent e) =>
      CrashModelStatusEvent(
        status: switch (e.status) {
          'unlocking' => CrashModelStatus.unlocking,
          'downloading' => CrashModelStatus.downloading,
          'decrypting' => CrashModelStatus.decrypting,
          'ready' => CrashModelStatus.ready,
          'failed' => CrashModelStatus.failed,
          'disabled' => CrashModelStatus.disabled,
          _ => CrashModelStatus.unknown,
        },
        detail: e.detail,
      );

  /// The current lifecycle stage.
  final CrashModelStatus status;

  /// Optional context — an error reason on [CrashModelStatus.failed], or extra
  /// info such as the tree count on [CrashModelStatus.ready].
  final String? detail;

  @override
  String toString() =>
      'CrashModelStatusEvent(${status.name}${detail != null ? ', $detail' : ''})';
}

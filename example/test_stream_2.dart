import 'dart:async';

class Location {
  final double speed;
  Location(this.speed);
  Location copyWithCoords({double? speed}) {
    return Location(speed ?? this.speed);
  }
}

void main() async {
  final controller = StreamController<Location>.broadcast();
  
  // Before my change:
  // final stream = controller.stream.where((l) => true).map((l) => l).asBroadcastStream();
  
  // After my change:
  final stream = controller.stream
    .expand((loc) {
      if (loc.speed == 0) {
        return [loc.copyWithCoords(speed: 1.5)];
      }
      return [loc];
    })
    .map((l) => l)
    .asBroadcastStream();

  stream.listen((loc) {
    print("Listen 1: \${loc.speed}");
  });

  stream.listen((loc) {
    print("Listen 2: \${loc.speed}");
  });

  controller.add(Location(0));
  controller.add(Location(2.0));
  
  await Future.delayed(Duration(seconds: 1));
}

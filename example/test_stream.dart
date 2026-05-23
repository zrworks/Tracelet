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
  final stream = controller.stream.expand((loc) {
    if (loc.speed == 0) {
      return [loc.copyWithCoords(speed: 1.5)];
    }
    return [loc];
  }).asBroadcastStream();

  stream.listen((loc) {
    print("Received: \${loc.speed}");
  });

  controller.add(Location(0));
  controller.add(Location(2.0));
  
  await Future.delayed(Duration(seconds: 1));
}

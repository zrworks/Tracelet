import re

disp_file = "sdk/rust-core/core/src/event_dispatcher/mod.rs"
with open(disp_file, "r") as f:
    content = f.read()

content = content.replace(
    "pub fn on_location_update(&self, lat: f64, lng: f64, accuracy: f64, speed: f64, heading: f64, altitude: f64, is_mock: bool) -> bool {",
    "pub fn on_location_update(&self, uuid: Option<String>, lat: f64, lng: f64, accuracy: f64, speed: f64, heading: f64, altitude: f64, is_mock: bool) -> bool {"
)

content = content.replace(
    "self.db.insert_location(lat, lng, accuracy, speed, heading, altitude, is_mock, &activity, route_context, None)",
    "self.db.insert_location(uuid, lat, lng, accuracy, speed, heading, altitude, is_mock, &activity, route_context, None)"
)

with open(disp_file, "w") as f:
    f.write(content)

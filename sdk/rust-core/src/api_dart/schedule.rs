use crate::algorithms::schedule_parser::{ScheduleParser as NativeParser, ScheduleAlarms as NativeAlarms};

pub struct ScheduleAlarmsDart {
    pub next_start_ms: i64,
    pub next_stop_ms: i64,
}

impl From<NativeAlarms> for ScheduleAlarmsDart {
    fn from(alarms: NativeAlarms) -> Self {
        Self {
            next_start_ms: alarms.next_start_ms,
            next_stop_ms: alarms.next_stop_ms,
        }
    }
}

pub struct ScheduleParserDart {
    inner: NativeParser,
}

impl ScheduleParserDart {
    #[flutter_rust_bridge::frb(sync)]
    #[flutter_rust_bridge::frb(sync)]
    pub fn new() -> Self {
        Self {
            inner: NativeParser::new(),
        }
    }

    #[flutter_rust_bridge::frb(sync)]
    #[flutter_rust_bridge::frb(sync)]
    pub fn is_within_schedule(&self, schedules: Vec<String>, timestamp_ms: i64, tz_offset_seconds: i32) -> bool {
        self.inner.is_within_schedule(schedules, timestamp_ms, tz_offset_seconds)
    }

    #[flutter_rust_bridge::frb(sync)]
    #[flutter_rust_bridge::frb(sync)]
    pub fn calculate_next_alarms(&self, schedules: Vec<String>, timestamp_ms: i64, tz_offset_seconds: i32) -> ScheduleAlarmsDart {
        self.inner.calculate_next_alarms(schedules, timestamp_ms, tz_offset_seconds).into()
    }
}

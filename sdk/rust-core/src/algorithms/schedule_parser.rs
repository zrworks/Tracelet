use chrono::{DateTime, Datelike, LocalResult, TimeZone, Timelike, Utc, FixedOffset};

/// Represents a parsed tracking schedule containing day and time bounds.
pub struct ParsedSchedule {
    pub day_start: u32,
    pub day_end: u32,
    pub start_hour: u32,
    pub start_minute: u32,
    pub end_hour: u32,
    pub end_minute: u32,
}

/// Contains the next absolute start and stop timestamps (in milliseconds) calculated from a schedule.
#[derive(uniffi::Record)]
pub struct ScheduleAlarms {
    pub next_start_ms: i64,
    pub next_stop_ms: i64,
}

/// Parses and evaluates tracking schedules to determine whether tracking should be active.
#[derive(uniffi::Object)]
pub struct ScheduleParser {}

#[uniffi::export]
impl ScheduleParser {
    /// Initializes a new instance of the ScheduleParser.
    #[uniffi::constructor]
    pub fn new() -> Self {
        Self {}
    }

    /// Determines whether the provided timestamp falls within any of the defined schedules.
    pub fn is_within_schedule(&self, schedules: Vec<String>, timestamp_ms: i64, tz_offset_seconds: i32) -> bool {
        if schedules.is_empty() {
            return false;
        }

        let tz = FixedOffset::east_opt(tz_offset_seconds).unwrap_or_else(|| FixedOffset::east_opt(0).unwrap());
        let dt = match Utc.timestamp_millis_opt(timestamp_ms) {
            LocalResult::Single(dt) => dt.with_timezone(&tz),
            _ => return false,
        };

        for schedule in schedules {
            if let Some(parsed) = Self::parse_schedule(&schedule) {
                if Self::matches_schedule(&parsed, &dt) {
                    return true;
                }
            }
        }
        false
    }

    /// Computes the next scheduled start and stop times, evaluating all provided schedules.
    pub fn calculate_next_alarms(&self, schedules: Vec<String>, timestamp_ms: i64, tz_offset_seconds: i32) -> ScheduleAlarms {
        let mut next_start_ms = i64::MAX;
        let mut next_stop_ms = i64::MAX;

        let tz = FixedOffset::east_opt(tz_offset_seconds).unwrap_or_else(|| FixedOffset::east_opt(0).unwrap());
        let dt = match Utc.timestamp_millis_opt(timestamp_ms) {
            LocalResult::Single(dt) => dt.with_timezone(&tz),
            _ => return ScheduleAlarms { next_start_ms, next_stop_ms },
        };

        for schedule in schedules {
            if let Some(parsed) = Self::parse_schedule(&schedule) {
                let (start, stop) = Self::calculate_alarms_for_schedule(&parsed, &dt);
                if start < next_start_ms {
                    next_start_ms = start;
                }
                if stop < next_stop_ms {
                    next_stop_ms = stop;
                }
            }
        }

        ScheduleAlarms { next_start_ms, next_stop_ms }
    }
}

impl ScheduleParser {
    fn parse_schedule(schedule: &str) -> Option<ParsedSchedule> {
        let parts: Vec<&str> = schedule.trim().split_whitespace().collect();
        if parts.len() != 2 {
            return None;
        }

        let day_range: Vec<&str> = parts[0].split('-').collect();
        let time_range: Vec<&str> = parts[1].split('-').collect();
        if day_range.len() != 2 || time_range.len() != 2 {
            return None;
        }

        let day_start = day_range[0].parse::<u32>().ok()?;
        let day_end = day_range[1].parse::<u32>().ok()?;

        let start_parts: Vec<&str> = time_range[0].split(':').collect();
        let end_parts: Vec<&str> = time_range[1].split(':').collect();
        if start_parts.len() != 2 || end_parts.len() != 2 {
            return None;
        }

        Some(ParsedSchedule {
            day_start,
            day_end,
            start_hour: start_parts[0].parse::<u32>().ok()?,
            start_minute: start_parts[1].parse::<u32>().ok()?,
            end_hour: end_parts[0].parse::<u32>().ok()?,
            end_minute: end_parts[1].parse::<u32>().ok()?,
        })
    }

    fn matches_schedule(parsed: &ParsedSchedule, dt: &DateTime<FixedOffset>) -> bool {
        let iso_day = dt.weekday().number_from_monday(); // 1=Mon, 7=Sun

        if iso_day < parsed.day_start || iso_day > parsed.day_end {
            return false;
        }

        let current_minutes = dt.hour() * 60 + dt.minute();
        let start_minutes = parsed.start_hour * 60 + parsed.start_minute;
        let end_minutes = parsed.end_hour * 60 + parsed.end_minute;

        current_minutes >= start_minutes && current_minutes < end_minutes
    }

    fn calculate_alarms_for_schedule(parsed: &ParsedSchedule, dt: &DateTime<FixedOffset>) -> (i64, i64) {
        // Construct the Start DateTime for today
        let mut start_dt = dt.with_hour(parsed.start_hour)
            .and_then(|d| d.with_minute(parsed.start_minute))
            .and_then(|d| d.with_second(0))
            .and_then(|d| d.with_nanosecond(0))
            .unwrap_or(*dt);

        // Construct the Stop DateTime for today
        let mut stop_dt = dt.with_hour(parsed.end_hour)
            .and_then(|d| d.with_minute(parsed.end_minute))
            .and_then(|d| d.with_second(0))
            .and_then(|d| d.with_nanosecond(0))
            .unwrap_or(*dt);

        if start_dt < *dt {
            // Next occurrence is tomorrow
            start_dt = start_dt + chrono::Duration::days(1);
        }
        
        if stop_dt < *dt {
            // Next occurrence is tomorrow
            stop_dt = stop_dt + chrono::Duration::days(1);
        }

        (start_dt.timestamp_millis(), stop_dt.timestamp_millis())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_schedule_parser() {
        let parser = ScheduleParser::new();
        let tz_offset = -25200; // PDT (-7 hours)
        
        // Tuesday May 26 2026 10:00:00 PDT
        let timestamp_ms = 1779814800000;
        
        // Match: Tuesday is within 1-5, 10:00 is within 09:00-17:00
        let schedules = vec!["1-5 09:00-17:00".to_string()];
        assert!(parser.is_within_schedule(schedules.clone(), timestamp_ms, tz_offset));
        
        let alarms = parser.calculate_next_alarms(schedules, timestamp_ms, tz_offset);
        // Next start should be tomorrow at 09:00 since we're past 09:00 today
        // Next stop should be today at 17:00
        assert!(alarms.next_start_ms > timestamp_ms);
        assert!(alarms.next_stop_ms > timestamp_ms);
    }
}

# Database Timestamp Migration Design (Issue 119 & 108)

## 1. Goal
Migrate the `location_events` database to use integer Unix milliseconds (`timestamp_ms`) for time-based querying instead of relying on string-based `julianday(timestamp)` evaluations. This provides O(log N) indexed query performance (fixing #119) and permanently eliminates string timezone parsing ambiguities (fixing #108).

## 2. Schema Changes
The database manager (`sdk/rust-core/core/src/database/mod.rs`) will be updated to:
- Append `timestamp_ms INTEGER DEFAULT 0` to the `CREATE TABLE location_events` statement.
- Add an `ALTER TABLE location_events ADD COLUMN timestamp_ms INTEGER` migration step for existing databases.
- Backfill existing data using SQLite's built-in date functions: `UPDATE location_events SET timestamp_ms = CAST((julianday(timestamp) - 2440587.5) * 86400000 AS INTEGER) WHERE timestamp_ms IS NULL OR timestamp_ms = 0;`
- Create a dedicated index: `CREATE INDEX IF NOT EXISTS idx_location_events_timestamp_ms ON location_events(timestamp_ms);`

## 3. Data Flow
- **Insertions**: The `insert_location` function will automatically compute the current time in Unix milliseconds and store it in `timestamp_ms` alongside the existing string `timestamp`.
- **Queries**: `get_locations_batch` will directly utilize the `timestamp_ms` column for `start_time_ms` and `end_time_ms` filtering (e.g. `timestamp_ms >= ?`).
- **Structs**: The `DbLocationRecord` does not strictly need `timestamp_ms` exposed to Dart since Dart already consumes the `timestamp` string, but we will keep `timestamp_ms` internally for purely native database operations.

## 4. Edge Cases & Safety
- **Corrupt Strings**: If older strings fail `julianday()` parsing during the migration, the `timestamp_ms` will default to `0`. This is acceptable as these records were already un-queryable by `julianday()`.
- **Backwards Compatibility**: The old `timestamp TEXT` column is preserved and kept synchronized so that existing Swift/Kotlin/Dart consumers that expect a string timestamp will not break.

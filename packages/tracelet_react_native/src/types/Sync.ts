/** Context passed to a custom sync-body builder. */
export interface SyncBodyContext {
  locations: Array<Record<string, unknown>>;
  telematics: Array<Record<string, unknown>>;
}

/** A function that builds a custom HTTP request body for sync. */
export type SyncBodyBuilder = (
  context: SyncBodyContext
) => Promise<Record<string, unknown>> | Record<string, unknown>;

/** A function that supplies dynamic HTTP headers (e.g. refreshed auth tokens). */
export type HeadersCallback = () =>
  | Promise<Record<string, string>>
  | Record<string, string>;

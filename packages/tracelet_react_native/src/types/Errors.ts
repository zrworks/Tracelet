/** Error thrown when a native Tracelet call fails. */
export class TraceletError extends Error {
  /** Native error code, e.g. `CONFIGURATION_ERROR`, `PERMISSION_DENIED`. */
  readonly code: string;

  constructor(code: string, message: string) {
    super(message);
    this.name = 'TraceletError';
    this.code = code;
    Object.setPrototypeOf(this, TraceletError.prototype);
  }
}

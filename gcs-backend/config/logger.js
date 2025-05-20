/**
 * @file Basic logger utility for the application.
 * Wraps console logging methods with simple prefixes (INFO, WARN, ERROR, DEBUG).
 */

/**
 * Logger object with methods for different log levels.
 * @namespace logger
 */
const logger = {
  /**
   * Logs an informational message.
   * @param {string} message - The main message to log.
   * @param {...any} args - Additional arguments to log, similar to console.log.
   * @memberof logger
   */
  info: (message, ...args) => console.log(`[INFO] ${message}`, ...args),

  /**
   * Logs a warning message.
   * @param {string} message - The main message to log.
   * @param {...any} args - Additional arguments to log, similar to console.warn.
   * @memberof logger
   */
  warn: (message, ...args) => console.warn(`[WARN] ${message}`, ...args),

  /**
   * Logs an error message.
   * @param {string} message - The main message to log.
   * @param {...any} args - Additional arguments to log, similar to console.error.
   * @memberof logger
   */
  error: (message, ...args) => console.error(`[ERROR] ${message}`, ...args),

  /**
   * Logs a debug message.
   * @param {string} message - The main message to log.
   * @param {...any} args - Additional arguments to log, similar to console.debug.
   * @memberof logger
   */
  debug: (message, ...args) => console.debug(`[DEBUG] ${message}`, ...args),
};

module.exports = logger; 
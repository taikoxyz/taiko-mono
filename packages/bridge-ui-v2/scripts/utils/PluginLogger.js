/* eslint-disable no-console */
const FgMagenta = '\x1b[35m';
const FgYellow = '\x1b[33m';
const FgRed = '\x1b[31m';
const Bright = '\x1b[1m';
const Reset = '\x1b[0m';

const timestamp = () => new Date().toLocaleTimeString();

export class PluginLogger {
  /**
   * @param {string} pluginName
   */
  constructor(pluginName) {
    this.pluginName = pluginName;
  }

  /**
   * @param {string} message
   */
  info(message) {
    this._logWithColor(FgMagenta, message);
  }

  /**
   * @param {any} message
   */
  warn(message) {
    this._logWithColor(FgYellow, message);
  }

  /**
   * @param {string} message
   */
  error(message) {
    this._logWithColor(FgRed, message, true);
  }

  /**
   * @param {string} color
   * @param {any} message
   */
  _logWithColor(color, message, isError = false) {
    console.log(
      `${color}${timestamp()}${Bright} [${this.pluginName}]${Reset}${isError ? color : ''} ${message} ${
        isError ? Reset : ''
      } `,
    );
  }
}

// Usage
// const logger = new Logger("plugin-name");

// logger.info("This is a log message.");  // Logs in magenta
// logger.warn("This is a warning message.");  // Logs in yellow
// logger.error("This is an error message.");  // Logs in red

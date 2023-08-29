/* eslint-disable no-console */
const FgMagenta = '\x1b[35m';
const FgYellow = '\x1b[33m';
const FgRed = '\x1b[31m';
const Bright = '\x1b[1m';
const Reset = '\x1b[0m';

const timestamp = () => new Date().toLocaleTimeString();

export class Logger {
  pluginName: string;

  constructor(pluginName: string) {
    this.pluginName = pluginName;
  }

  info(message: string) {
    this._logWithColor(FgMagenta, message);
  }

  warn(message: string) {
    this._logWithColor(FgYellow, message);
  }

  error(message: string) {
    this._logWithColor(FgRed, message, true);
  }

  _logWithColor(color: string, message: string, isError = false) {
    console.log(
      `${color}${timestamp()}${Bright} [${this.pluginName}]${Reset}${isError ? color : ''} ${message} ${
        isError ? Reset : ''
      } `,
    );
  }
}

// Usage
// const logger = new Logger("plugin-name");

// logger.log("This is a log message.");  // Logs in magenta
// logger.warn("This is a warning message.");  // Logs in yellow
// logger.error("This is an error message.");  // Logs in red

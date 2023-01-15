import * as chalk from "chalk";

// default LOG_LEVEL: INFO
function isInfoEnabled() {
    return (
        !process.env.LOG_LEVEL ||
        (process.env.LOG_LEVEL &&
            process.env.LOG_LEVEL.toUpperCase() === "INFO") ||
        isDebugEnabled()
    );
}

function isDebugEnabled() {
    return (
        process.env.LOG_LEVEL && process.env.LOG_LEVEL.toUpperCase() === "DEBUG"
    );
}

export function info(...args: any[]) {
    if (isInfoEnabled()) {
        console.log(chalk.blue.bold(["[INFO]", ...args].join(" ")));
    }
}

export function debug(...args: any[]) {
    if (isDebugEnabled()) {
        console.log(...args);
    }
}

export function warn(...args: any[]) {
    console.log(chalk.magenta.bold(["[WARN]", ...args].join(" ")));
}

export function error(...args: any[]) {
    console.log(chalk.red.bold.underline(["[ERROR]", ...args].join(" ")));
}

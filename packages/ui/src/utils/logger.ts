import { isProduction, isTest } from "./isProduction";
import { get } from "svelte/store";
import { errorTracker } from "../store/errorTracker";
import type { ErrorTracker } from "../domain/errorTracker";

const logger = {
  log: function (...parameters: unknown[]) {
    if (!isProduction() && !isTest()) {
      console.log(...parameters);
    }
  },
  warn: function (...parameters: unknown[]) {
    if (!isProduction()) {
      console.warn(...parameters);
    }
  },
  error: function (...parameters: unknown[]) {
    if (!isProduction()) {
      console.error(...parameters);
    }
    const $errorTracker: ErrorTracker = get(errorTracker);
    if ($errorTracker) {
      if (parameters.length > 1 && typeof parameters[0] === "string") {
        $errorTracker.captureError(parameters[1], parameters[0]);
      } else {
        const error: unknown = parameters.find((p) => typeof p === "object");
        if (error) {
          $errorTracker.captureError(error);
        } else {
          $errorTracker.captureError(parameters[0]);
        }
      }
    }
  },
};

export default logger;

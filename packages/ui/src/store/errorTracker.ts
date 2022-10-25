import { writable } from "svelte/store";
import type { ErrorTracker } from "../domain/errorTracker";

const errorTracker = writable<ErrorTracker>();

export { errorTracker };

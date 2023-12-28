import type { Guardian } from "$lib/types";
import { writable } from "svelte/store";

export const selectedGuardianProver = writable<Guardian>();
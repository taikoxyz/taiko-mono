import { PageTabs } from "$lib/types";
import { writable } from "svelte/store";

export const selectedTab = writable<PageTabs>(PageTabs.GUARDIAN_PROVER);
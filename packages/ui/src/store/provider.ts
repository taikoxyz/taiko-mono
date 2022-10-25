import type { ethers } from "ethers";
import { writable } from "svelte/store";

const provider = writable<ethers.providers.ExternalProvider>();

export { provider };

import type { ethers } from "ethers";
import { writable } from "svelte/store";

const signer = writable<ethers.Signer>();

export { signer };

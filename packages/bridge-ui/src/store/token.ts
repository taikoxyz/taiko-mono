import { writable } from "svelte/store";
import { ETH } from "../domain/token";
import type { Token } from "../domain/token";

export const token = writable<Token>(ETH);

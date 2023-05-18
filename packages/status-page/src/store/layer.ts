import { Layer } from "../domain/layer";
import { writable } from "svelte/store";

export const layer = writable<Layer>(Layer.Two);

import { Layer } from "../domain/layer";

export const layerToDisplayName = (layer: Layer) =>
  layer === Layer.Two ? "Taiko L2" : "Taiko L3";

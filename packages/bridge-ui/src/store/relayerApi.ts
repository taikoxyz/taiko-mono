import type { RelayerAPI, RelayerBlockInfo } from "../domain/relayerApi";
import { writable } from "svelte/store";
import RelayerAPIService from "../relayer-api/service";
import type { ethers } from "ethers";

const relayerApi = writable<RelayerAPI>();
const relayerBlockInfoMap = writable<Map<number, RelayerBlockInfo>>();

export { relayerApi, relayerBlockInfoMap };

export function setRelayer(
  providerMap: Map<number, ethers.providers.JsonRpcProvider>,
  relayerURL: string
) {
  const relayerApiService: RelayerAPI = new RelayerAPIService(
    providerMap,
    relayerURL
  );

  relayerApi.set(relayerApiService);

  return relayerApi;
}

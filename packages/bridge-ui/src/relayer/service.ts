import type { BridgeTransaction, Transactioner } from "../domain/transactions";
import { Axios } from "axios";
import type { AxiosResponse } from "axios";
class RelayerService implements Transactioner {
  private readonly relayerURL;
  private readonly axios: Axios;

  constructor(relayerURL: string) {
    this.relayerURL = relayerURL;
    this.axios = new Axios({
      baseURL: relayerURL,
    });
  }

  async GetAllByAddress(
    address: string,
    chainID: number
  ): Promise<BridgeTransaction[]> {
    const resp: AxiosResponse<BridgeTransaction[]> = await this.axios.get<
      BridgeTransaction[]
    >(`/events`, {
      params: {
        address: address,
        chainID: chainID,
      },
    });

    return resp.data;
  }
}

export { RelayerService };

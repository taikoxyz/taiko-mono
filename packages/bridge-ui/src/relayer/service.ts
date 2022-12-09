import type {
  BridgeTransaction,
  Data,
  Transactioner,
} from "../domain/transactions";
import { Axios } from "axios";
import type { AxiosResponse } from "axios";
class RelayerService implements Transactioner {
  private readonly axios: Axios;

  constructor(relayerURL: string) {
    this.axios = new Axios({
      baseURL: relayerURL,
    });
  }

  async GetAllByAddress(
    address: string,
    chainID?: number
  ): Promise<BridgeTransaction[]> {
    const params: { address: string; chainID?: number } = {
      address: address,
    };

    if (chainID) {
      params.chainID = chainID;
    }

    const resp: AxiosResponse<BridgeTransaction[]> = await this.axios.get<
      BridgeTransaction[]
    >(`/events`, {
      params: params,
      headers: {
        Accept: "*/*",
      },
    });

    const txs = resp.data.map((tx) => {
      const rawData: Data = JSON.parse(tx.data);
      tx.rawData = rawData;
      return tx;
    });

    return txs;
  }
}

export { RelayerService };

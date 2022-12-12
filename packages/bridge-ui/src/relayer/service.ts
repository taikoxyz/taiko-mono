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
      transitional: {
        silentJSONParsing: false,
      },
      responseType: "json",
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

    const resp: AxiosResponse = await this.axios.get(`/events`, {
      params: params,
      headers: {
        Accept: "*/*",
        "Content-Type": "application/json",
      },
    });

    const bridgeTxs: BridgeTransaction[] = JSON.parse(resp.data);

    const parsed = bridgeTxs.map((tx) => {
      const rawData: Data = JSON.parse(tx.data);
      tx.rawData = rawData;
      return tx;
    });

    console.log(parsed);

    return parsed;
  }
}

export { RelayerService };

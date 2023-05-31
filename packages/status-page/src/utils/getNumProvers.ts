import axios from "axios";

export type UniqueProver = {
  address: string;
  count: number;
};
export type UniqueProverResponse = {
  uniqueProvers: number;
  provers: UniqueProver[];
};
export const getNumProvers = async (
  eventIndexerApiUrl: string
): Promise<UniqueProverResponse> => {
  const uniqueProversResp = await axios.get<UniqueProverResponse>(
    `${eventIndexerApiUrl}/uniqueProvers`
  );

  if (uniqueProversResp.data) {
    uniqueProversResp.data.provers.sort((a, b) => b.count - a.count);
    // Filter out the oracle prover address since it doesn't submit the actual zk proof
    const index = uniqueProversResp.data.provers.findIndex(
      (uniqueProver) =>
        uniqueProver.address === "0x0000000000000000000000000000000000000000"
    );
    if (index > -1) {
      uniqueProversResp.data.provers.splice(index, 1);
      uniqueProversResp.data.uniqueProvers--;
    }
    // Filter out the system prover address since it doesn't submit the actual zk proof
    const systemIndex = uniqueProversResp.data.provers.findIndex(
      (uniqueProver) =>
        uniqueProver.address === "0x0000000000000000000000000000000000000001"
    );
    if (systemIndex > -1) {
      uniqueProversResp.data.provers.splice(systemIndex, 1);
      uniqueProversResp.data.uniqueProvers--;
    }
  }

  return uniqueProversResp.data || { uniqueProvers: 0, provers: [] };
};

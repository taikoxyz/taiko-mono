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
  const resp = await axios.get<UniqueProverResponse>(
    `${eventIndexerApiUrl}/uniqueProvers`
  );
  let uniqueProverRes = resp.data;
  uniqueProverRes.provers.sort((a, b) => b.count - a.count);
  return uniqueProverRes;
};

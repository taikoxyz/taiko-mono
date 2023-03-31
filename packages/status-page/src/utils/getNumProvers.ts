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
  const uniqueProverResp = await axios.get<UniqueProverResponse>(
    `${eventIndexerApiUrl}/uniqueProvers`
  );
  uniqueProverResp.data.provers.sort((a, b) => b.count - a.count);

  return uniqueProverResp.data;
};

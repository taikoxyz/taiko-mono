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
  return resp.data;
};

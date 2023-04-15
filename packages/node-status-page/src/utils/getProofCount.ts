import axios from "axios";

export type GetProofCountResponse = {
  count: number;
};
export const getProofCount = async (
  eventIndexerApiUrl: string,
  address: string
): Promise<number> => {
  const getProofCountResp = await axios.get<GetProofCountResponse>(
    `${eventIndexerApiUrl}/eventByAddress`,
    {
      params: {
        address: address,
        event: "BlockProven",
      },
    }
  );

  return getProofCountResp.data?.count || 0;
};

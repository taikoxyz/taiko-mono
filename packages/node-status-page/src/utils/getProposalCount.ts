import axios from "axios";

export type GetProposalCountResponse = {
  count: number;
};

export const getProposalCount = async (
  eventIndexerApiUrl: string,
  address: string
): Promise<number> => {
  const getProposalCountResp = await axios.get<GetProposalCountResponse>(
    `${eventIndexerApiUrl}/eventByAddress`,
    {
      params: {
        address: address,
        event: "BlockProposed",
      },
    }
  );

  return getProposalCountResp.data?.count || 0;
};

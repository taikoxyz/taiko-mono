import axios from "axios";

export type UniqueProposer = {
  address: string;
  count: number;
};
export type UniqueProverResponse = {
  uniqueProposers: number;
  proposers: UniqueProposer[];
};

export const getNumProposers = async (
  eventIndexerApiUrl: string
): Promise<UniqueProverResponse> => {
  const uniqueProposersResp = await axios.get<UniqueProverResponse>(
    `${eventIndexerApiUrl}/uniqueProposers`
  );

  if (uniqueProposersResp.data) {
    uniqueProposersResp.data.proposers.sort((a, b) => b.count - a.count);
  }

  return uniqueProposersResp.data || { uniqueProposers: 0, proposers: [] };
};

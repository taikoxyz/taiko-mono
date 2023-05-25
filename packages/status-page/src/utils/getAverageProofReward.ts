import axios from "axios";
import { ethers } from "ethers";

export type StatsResponse = {
  id: number;
  averageProofTime: number;
  averageProofReward: number;
  numProofs: number;
};
export const getAverageProofReward = async (
  eventIndexerApiUrl: string
): Promise<string> => {
  const resp = await axios.get<StatsResponse>(`${eventIndexerApiUrl}/stats`);

  return `${ethers.utils.formatUnits(resp.data.averageProofReward)} TKO`;
};

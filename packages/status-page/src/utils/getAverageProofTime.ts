import axios from "axios";
import type { StatsResponse } from "./getAverageProofReward";

export const getAverageProofTime = async (
  eventIndexerApiUrl: string
): Promise<string> => {
  const resp = await axios.get<StatsResponse>(`${eventIndexerApiUrl}/stats`);

  return `${resp.data.averageProofTime}`;
};

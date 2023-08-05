import axios from 'axios';
import type { ethers } from 'ethers';
import type { APIResponse, APIResponseEvent } from 'src/domain/api';

export const getSlashedTokensEvents = async (
  eventIndexerApiUrl: string,
  signer: ethers.Signer,
): Promise<APIResponseEvent[]> => {
  if (!signer) return;

  const resp = await axios.get<APIResponse>(`${eventIndexerApiUrl}/events`, {
    params: {
      event: 'Slashed',
      address: await signer.getAddress(),
    },
  });

  return resp.data.items;
};

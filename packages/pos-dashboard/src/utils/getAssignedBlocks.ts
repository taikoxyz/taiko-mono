import axios from 'axios';
import type { ethers } from 'ethers';
import type { APIResponse, APIResponseEvent } from 'src/domain/api';

export const getAssignedBlocks = async (
  eventIndexerApiUrl: string,
  signer: ethers.Signer,
): Promise<APIResponseEvent[]> => {
  const resp = await axios.get<APIResponse>(
    `${eventIndexerApiUrl}/assignedBlocks`,
    {
      params: {
        address: await signer.getAddress(),
      },
    },
  );
  return resp.data.items.map((item) => {
    item.amount = '0';
    return item;
  });
};

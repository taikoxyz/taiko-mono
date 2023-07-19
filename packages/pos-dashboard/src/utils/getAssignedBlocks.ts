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
        address: '0x67acA3B6D5b5744c8e8abf7661734A7344EE0bcC',
      },
    },
  );
  return resp.data.items.map((item) => {
    item.amount = '0';
    return item;
  });
};

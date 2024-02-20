import axios from 'axios';
import { zeroAddress } from 'viem';

import { EventIndexerAPIService } from './EventIndexerAPIService';

vi.mock('axios');

describe('EventIndexerAPIService', () => {
  it('should fetch NFTs by address', async () => {
    const mockData = { data: 'mockData' };
    vi.mocked(axios.get).mockResolvedValue({ status: 200, data: mockData });

    const service = new EventIndexerAPIService('https://api.example.com');
    const result = await service.getNftsByAddress({ address: zeroAddress, chainID: 1n });

    expect(result).toEqual(mockData);
    expect(axios.get).toHaveBeenCalledWith('https://api.example.com/nftsByAddress', expect.any(Object));
  });

  it('should throw an error on API failure', async () => {
    vi.mocked(axios.get).mockResolvedValue({ status: 500 });
    const service = new EventIndexerAPIService('https://api.example.com');
    await expect(service.getNftsByAddress({ address: zeroAddress, chainID: 1n })).rejects.toThrow(
      'could not fetch transactions from API',
    );
    expect(axios.get).toHaveBeenCalledWith('https://api.example.com/nftsByAddress', expect.any(Object));
  });

  it('should fetch all NFTs by address', async () => {
    const mockData = { data: 'mockData' };
    const mockGetNftsByAddress = vi.fn().mockImplementation(() => Promise.resolve(mockData));
    const service = new EventIndexerAPIService('https://api.example.com');
    service.getNftsByAddress = mockGetNftsByAddress;

    const result = await service.getAllNftsByAddressFromAPI(zeroAddress, 1n, {
      size: 1,
      page: 2,
    });

    expect(result).toEqual(mockData);
  });
});

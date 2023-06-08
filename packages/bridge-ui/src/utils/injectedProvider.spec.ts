import { ethers } from 'ethers';

import { rpcCall } from './injectedProvider';

jest.mock('../constants/envVars');

jest.mock('ethers', () => {
  const Web3Provider = jest.fn();
  Web3Provider.prototype = {
    send: jest.fn(),
  };

  return {
    ethers: {
      providers: {
        Web3Provider,
      },
    },
  };
});

describe('injectedProvider - rpcCall', () => {
  it('should call rpc method', async () => {
    jest
      .mocked(ethers.providers.Web3Provider.prototype.send)
      .mockResolvedValueOnce('test value');

    const result = await rpcCall('eth_requestAccounts');

    expect(result).toEqual('test value');
    expect(ethers.providers.Web3Provider.prototype.send).toHaveBeenCalledWith(
      'eth_requestAccounts',
      undefined,
    );
  });

  it('should throw error if rpc method fails', async () => {
    jest
      .mocked(ethers.providers.Web3Provider.prototype.send)
      .mockRejectedValue(new Error('test error'));

    await expect(rpcCall('eth_requestAccounts')).rejects.toThrowError(
      'RPC call "eth_requestAccounts" failed',
    );
  });
});

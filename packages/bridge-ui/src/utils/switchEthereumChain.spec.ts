import type { Ethereum } from '@wagmi/core';
import type { Chain } from '../domain/chain';
import { ethers } from 'ethers';
import { switchEthereumChain } from './switchEthereumChain';

const ethereum = {
  request: jest.fn(),
};

const chain = {
  id: 1,
  name: 'Ethereum Mainnet',
  rpc: 'rpc',
  explorerUrl: '',
  bridgeAddress: '',
  headerSyncAddress: '',
} as Chain;

describe('switchEthereumChain()', () => {
  beforeEach(() => {
    jest.resetAllMocks();
  });

  it('should switchEthereumChain switches to the correct chain', async () => {
    await switchEthereumChain(ethereum as unknown as Ethereum, chain);
    expect(ethereum.request).toHaveBeenCalledWith({
      method: 'wallet_switchEthereumChain',
      params: [{ chainId: '0x1' }],
    });
  });

  it('should addChain when ethereum thros chain not exist error', async () => {
    class EthereumError extends Error {
      code: number;
      constructor(code) {
        super();
        this.code = code;
      }
    }

    ethereum.request.mockImplementationOnce(() => {
      const error = new EthereumError(4902);
      throw error;
    });

    await switchEthereumChain(ethereum as unknown as Ethereum, chain);
    expect(ethereum.request).toHaveBeenCalledWith({
      method: 'wallet_addEthereumChain',
      params: [
        {
          chainId: ethers.utils.hexValue(chain.id),
          chainName: chain.name,
          rpcUrls: [chain.rpc],
          nativeCurrency: {
            symbol: 'ETH',
            decimals: 18,
            name: 'Ethereum',
          },
        },
      ],
    });
  });
});

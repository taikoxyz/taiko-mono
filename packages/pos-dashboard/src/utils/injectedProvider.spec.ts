import { ethers } from 'ethers';

import {
  getInjectedSigner,
  hasInjectedProvider,
  rpcCall,
} from './injectedProvider';

jest.mock('../constants/envVars');

jest.mock('ethers', () => {
  const Web3Provider = jest.fn();
  Web3Provider.prototype = {
    getSigner: jest.fn(),
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

beforeEach(() => {
  globalThis.ethereum = {
    isMetaMask: true,
    request: jest.fn(),
  };

  jest.clearAllMocks();
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

describe('injectedProvider - getInjectedSigner', () => {
  it('should return signer', () => {
    const mockSigner = {} as ethers.providers.JsonRpcSigner;
    jest
      .mocked(ethers.providers.Web3Provider.prototype.getSigner)
      .mockReturnValue(mockSigner);

    expect(getInjectedSigner()).toEqual(mockSigner);

    expect(ethers.providers.Web3Provider).toHaveBeenCalledWith(
      globalThis.ethereum,
      'any',
    );
  });
});

describe('injectedProvider - hasInjectedProvider', () => {
  it('should return true if injected provider is available', () => {
    expect(hasInjectedProvider()).toBeTruthy();
  });

  it('should return false if injected provider is not available', () => {
    globalThis.ethereum = undefined;

    expect(hasInjectedProvider()).toBeFalsy();
  });
});

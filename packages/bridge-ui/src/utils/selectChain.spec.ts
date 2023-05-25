import { switchNetwork } from '@wagmi/core';
import { ethers } from 'ethers';

import { mainnetChain, taikoChain } from '../chain/chains';
import { fromChain, toChain } from '../store/chain';
import { signer } from '../store/signer';
import { selectChain } from './selectChain';

jest.mock('../constants/envVars');

jest.mock('@wagmi/core', () => ({
  switchNetwork: jest.fn(),
}));

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

jest.mock('../store/chain', () => ({
  fromChain: {
    set: jest.fn(),
  },
  toChain: {
    set: jest.fn(),
  },
}));

jest.mock('../store/signer', () => ({
  signer: {
    set: jest.fn(),
  },
}));

const mockSigner = {} as ethers.providers.JsonRpcSigner;

describe('selectChain', () => {
  beforeAll(() => {
    jest
      .mocked(ethers.providers.Web3Provider.prototype.getSigner)
      .mockReturnValue(mockSigner);
  });

  beforeEach(() => {
    jest.mocked(ethers.providers.Web3Provider.prototype.getSigner).mockClear();
  });

  it('should select chain', async () => {
    await selectChain(mainnetChain);

    expect(switchNetwork).toHaveBeenCalledWith({ chainId: mainnetChain.id });
    expect(fromChain.set).toHaveBeenCalledWith(mainnetChain);
    expect(toChain.set).toHaveBeenCalledWith(taikoChain);

    expect(ethers.providers.Web3Provider.prototype.send).toHaveBeenCalledWith(
      'eth_requestAccounts',
      [],
    );

    // By default the signer is not updated as
    // there might be no change in the account.
    expect(
      ethers.providers.Web3Provider.prototype.getSigner,
    ).toHaveBeenCalled();

    expect(signer.set).toHaveBeenCalledWith(mockSigner);

    // Select the other chain now
    await selectChain(taikoChain);

    expect(switchNetwork).toHaveBeenCalledWith({ chainId: taikoChain.id });
  });
});

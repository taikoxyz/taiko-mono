import { fetchSigner, switchNetwork } from '@wagmi/core';
import type { ethers } from 'ethers';

import { mainnetChain, taikoChain } from '../chain/chains';
import { signer } from '../store/signer';
import { selectChain } from './selectChain';

jest.mock('../constants/envVars');

jest.mock('@wagmi/core', () => ({
  switchNetwork: jest.fn(),
  fetchSigner: jest.fn(),
}));

jest.mock('../store/signer', () => ({
  signer: {
    set: jest.fn(),
  },
}));

const mockSigner = {} as ethers.providers.JsonRpcSigner;

describe('selectChain', () => {
  it('should select chain', async () => {
    jest.mocked(fetchSigner).mockResolvedValueOnce(mockSigner);

    await selectChain(mainnetChain);

    expect(switchNetwork).toHaveBeenCalledWith({ chainId: mainnetChain.id });
    expect(fetchSigner).toHaveBeenCalled();

    expect(signer.set).toHaveBeenCalledWith(mockSigner);

    // Select the other chain now
    await selectChain(taikoChain);

    expect(switchNetwork).toHaveBeenCalledWith({ chainId: taikoChain.id });
  });
});

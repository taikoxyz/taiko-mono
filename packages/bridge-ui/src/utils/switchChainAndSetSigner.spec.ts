import { fetchSigner, switchNetwork } from '@wagmi/core';
import { ethers, Signer } from 'ethers';
import { L1_CHAIN_ID, L2_CHAIN_ID } from '../constants/envVars';
import { chains, mainnetChain, taikoChain } from '../chain/chains';
import { fromChain, toChain } from '../store/chain';
import { signer } from '../store/signer';
import { switchChainAndSetSigner } from './switchChainAndSetSigner';

jest.mock('@wagmi/core');
jest.mock('ethers');
jest.mock('../constants/envVars');
jest.mock('../store/chain');
jest.mock('../store/signer');

describe('switchChainAndSetSigner', () => {
  const mockWagmiSigner = {} as Signer;
  const mockSwitchNetwork = jest.mocked(switchNetwork);
  const mockFetchSigner = jest.mocked(fetchSigner);
  const mockSend = jest.mocked(ethers.providers.Web3Provider.prototype.send);
  const mockFromChainSet = jest.mocked(fromChain.set);
  const mockToChainSet = jest.mocked(toChain.set);
  const mockSignerSet = jest.mocked(signer.set);

  beforeAll(() => {
    mockSwitchNetwork.mockResolvedValue(undefined);
    mockFetchSigner.mockResolvedValue(mockWagmiSigner);
    mockSend.mockResolvedValue(undefined);
  });

  beforeEach(() => {
    mockToChainSet.mockClear();
  });

  it('should switch to taiko chain and set signer', async () => {
    const chain = chains[L1_CHAIN_ID];
    await switchChainAndSetSigner(chain);

    // Make sure all the internal functions have been called
    // with the correct arguments
    expect(mockSwitchNetwork).toHaveBeenCalledWith({ chainId: chain.id });
    expect(mockFetchSigner).toHaveBeenCalledWith({ chainId: chain.id });
    expect(mockSend).toHaveBeenCalledWith('eth_requestAccounts', []);
    expect(mockFromChainSet).toHaveBeenCalledWith(chain);
    expect(mockToChainSet).toHaveBeenCalledWith(taikoChain);
    expect(mockSignerSet).toHaveBeenCalledWith(mockWagmiSigner);
  });

  it('should switch to mainnet chain', async () => {
    const chain = chains[L2_CHAIN_ID];
    await switchChainAndSetSigner(chain);

    expect(mockToChainSet).toHaveBeenCalledWith(mainnetChain);
  });
});

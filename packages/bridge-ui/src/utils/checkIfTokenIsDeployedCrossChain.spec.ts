import { ethers } from 'ethers';

import { tokenVaultABI } from '../constants/abi';
import type { Chain } from '../domain/chain';
import type { Token } from '../domain/token';
import { ETHToken } from '../token/tokens';
import { checkIfTokenIsDeployedCrossChain } from './checkIfTokenIsDeployedCrossChain';

jest.mock('../constants/envVars');

// mock the `ethers.providers.JsonRpcProvider` object for testing purposes
const provider = new ethers.providers.JsonRpcProvider();

describe('checkIfTokenIsDeployedCrossChain', () => {
  const token: Token = {
    name: 'Test Token',
    symbol: 'TEST',
    decimals: 18,
    logoComponent: null,
    addresses: {
      1: '0x0000000000000000000000000000000000000001',
      4: '0x0000000000000000000000000000000000000002',
      5: '0x00',
    },
  };
  const destTokenVaultAddress = '0x0000000000000000000000000000000000000004';

  const destChain: Chain = {
    id: 5,
    name: 'MyChain',
    rpc: 'http://mychain.rpc.com',
    explorerUrl: '',
    signalServiceAddress: '0x1234567890',
    bridgeAddress: '0x1234567890',
    crossChainSyncAddress: '0x0987654321',
  };

  const srcChain: Chain = {
    id: 1,
    name: 'SomeOtherChain',
    rpc: 'http://otherchain.rpc.com',
    explorerUrl: '',
    signalServiceAddress: '0x9876543210',
    bridgeAddress: '0x9876543210',
    crossChainSyncAddress: '0x0123456789',
  };

  it('should return false when the token is ETH', async () => {
    const ethToken: Token = {
      ...token,
      symbol: ETHToken.symbol,
      addresses: {},
    };
    const result = await checkIfTokenIsDeployedCrossChain(
      ethToken,
      provider,
      destTokenVaultAddress,
      destChain,
      srcChain,
    );
    expect(result).toBeFalsy();
  });

  it('should return false when the token is not deployed on the destination chain', async () => {
    // mock the `ethers.Contract` object for testing purposes
    const destTokenVaultContract = {
      canonicalToBridged: jest
        .fn()
        .mockResolvedValue(ethers.constants.AddressZero),
    };
    jest
      .spyOn(ethers, 'Contract')
      .mockReturnValue(destTokenVaultContract as any);

    const result = await checkIfTokenIsDeployedCrossChain(
      token,
      provider,
      destTokenVaultAddress,
      destChain,
      srcChain,
    );
    expect(result).toBeFalsy();

    expect(ethers.Contract).toHaveBeenCalledWith(
      destTokenVaultAddress,
      tokenVaultABI,
      provider,
    );
    expect(destTokenVaultContract.canonicalToBridged).toHaveBeenCalledWith(
      srcChain.id,
      token.addresses[srcChain.id],
    );
  });

  it('should return true when the token is deployed as BridgedERC20 on the destination chain', async () => {
    const bridgedTokenAddress = '0x00';
    // mock the `ethers.Contract` object for testing purposes
    const destTokenVaultContract = {
      canonicalToBridged: jest.fn().mockResolvedValue(bridgedTokenAddress),
    };
    jest
      .spyOn(ethers, 'Contract')
      .mockReturnValue(destTokenVaultContract as any);

    const result = await checkIfTokenIsDeployedCrossChain(
      token,
      provider,
      destTokenVaultAddress,
      destChain,
      srcChain,
    );
    expect(result).toBeTruthy();

    expect(ethers.Contract).toHaveBeenCalledWith(
      destTokenVaultAddress,
      tokenVaultABI,
      provider,
    );
    expect(destTokenVaultContract.canonicalToBridged).toHaveBeenCalledWith(
      srcChain.id,
      token.addresses[srcChain.id],
    );
  });

  it('catches and rethrows error when canonicalToBridged method fails', async () => {
    const destTokenVaultContract = {
      canonicalToBridged: jest.fn().mockRejectedValue(new Error('BOOM!!')),
    };

    jest
      .spyOn(ethers, 'Contract')
      .mockReturnValue(destTokenVaultContract as any);

    await expect(
      checkIfTokenIsDeployedCrossChain(
        token,
        provider,
        destTokenVaultAddress,
        destChain,
        srcChain,
      ),
    ).rejects.toThrow(
      'encountered an issue when checking if token is deployed cross-chain',
    );
  });
});

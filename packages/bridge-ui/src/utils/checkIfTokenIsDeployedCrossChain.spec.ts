import { ethers } from 'ethers';
import { ETHToken } from '../token/tokens';
import { tokenVaultABI } from '../constants/abi';
import type { Chain } from '../domain/chain';
import type { Token } from '../domain/token';
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
    addresses: [
      { chainId: 1, address: '0x0000000000000000000000000000000000000001' },
      { chainId: 4, address: '0x0000000000000000000000000000000000000002' },
      { chainId: 5, address: '0x00' },
    ],
  };
  const destTokenVaultAddress = '0x0000000000000000000000000000000000000004';

  const toChain: Chain = {
    id: 5,
    name: 'MyChain',
    rpc: 'http://mychain.rpc.com',
    explorerUrl: '',
    signalServiceAddress: '',
    bridgeAddress: '0x1234567890',
    crossChainSyncAddress: '0x0987654321',
  };

  const fromChain: Chain = {
    id: 1,
    name: 'SomeOtherChain',
    rpc: 'http://otherchain.rpc.com',
    explorerUrl: '',
    signalServiceAddress: '',
    bridgeAddress: '0x9876543210',
    crossChainSyncAddress: '0x0123456789',
  };

  it('should return false when the token is ETH', async () => {
    const ethToken: Token = {
      ...token,
      symbol: ETHToken.symbol,
      addresses: [],
    };
    const result = await checkIfTokenIsDeployedCrossChain(
      ethToken,
      provider,
      destTokenVaultAddress,
      toChain,
      fromChain,
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
      toChain,
      fromChain,
    );
    expect(result).toBeFalsy();

    expect(ethers.Contract).toHaveBeenCalledWith(
      destTokenVaultAddress,
      tokenVaultABI,
      provider,
    );
    expect(destTokenVaultContract.canonicalToBridged).toHaveBeenCalledWith(
      fromChain.id,
      token.addresses.find((a) => a.chainId === fromChain.id)?.address,
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
      toChain,
      fromChain,
    );
    expect(result).toBeTruthy();

    expect(ethers.Contract).toHaveBeenCalledWith(
      destTokenVaultAddress,
      tokenVaultABI,
      provider,
    );
    expect(destTokenVaultContract.canonicalToBridged).toHaveBeenCalledWith(
      fromChain.id,
      token.addresses.find((a) => a.chainId === fromChain.id)?.address,
    );
  });

  it('catches and rethrows error when canonicalToBridged method fails', async () => {
    const destTokenVaultContract = {
      canonicalToBridged: jest.fn().mockRejectedValue(new Error('test error')),
    };

    jest
      .spyOn(ethers, 'Contract')
      .mockReturnValue(destTokenVaultContract as any);

    await expect(
      checkIfTokenIsDeployedCrossChain(
        token,
        provider,
        destTokenVaultAddress,
        toChain,
        fromChain,
      ),
    ).rejects.toThrow(
      'encountered an issue when checking if token is deployed cross-chain',
    );
  });
});

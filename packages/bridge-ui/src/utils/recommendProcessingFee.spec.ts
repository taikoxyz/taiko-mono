import { BigNumber, ethers, Signer } from 'ethers';
import { get } from 'svelte/store';

import { mainnetChain, taikoChain } from '../chain/chains';
import { L1_CHAIN_ID, L2_CHAIN_ID } from '../constants/envVars';
import { ProcessingFeeMethod } from '../domain/fee';
import type { Token } from '../domain/token';
import { providers } from '../provider/providers';
import { signer } from '../store/signer';
import { ETHToken, testERC20Tokens } from '../token/tokens';
import {
  erc20DeployedGasLimit,
  erc20NotDeployedGasLimit,
  ethGasLimit,
  recommendProcessingFee,
} from './recommendProcessingFee';

jest.mock('../constants/envVars');

const mockContract = {
  canonicalToBridged: jest.fn(),
};

jest.mock('ethers', () => ({
  ...jest.requireActual('ethers'),
  Contract: function () {
    return mockContract;
  },
}));

const gasPrice = 2;
const mockGetGasPrice = async () => Promise.resolve(BigNumber.from(gasPrice));

// Mocking providers to return the desired gasPrice
providers[mainnetChain.id].getGasPrice = mockGetGasPrice;
providers[taikoChain.id].getGasPrice = mockGetGasPrice;

const mockSigner = {} as Signer;

const mockToken = {
  name: 'MockToken',
  addresses: {
    [L1_CHAIN_ID]: '0x00',
    [L2_CHAIN_ID]: '0x123', // token is deployed on L2
  },
  decimals: 18,
  symbol: 'MKT',
  logoComponent: null,
} as Token;

describe('recommendProcessingFee()', () => {
  beforeEach(() => {
    jest.resetAllMocks();
  });

  it('returns zero if values not set', async () => {
    expect(
      await recommendProcessingFee(
        null,
        mainnetChain,
        ProcessingFeeMethod.RECOMMENDED,
        ETHToken,
        get(signer),
      ),
    ).toEqual('0');

    expect(
      await recommendProcessingFee(
        mainnetChain,
        null,
        ProcessingFeeMethod.RECOMMENDED,
        ETHToken,
        get(signer),
      ),
    ).toEqual('0');

    expect(
      await recommendProcessingFee(
        mainnetChain,
        taikoChain,
        null,
        ETHToken,
        get(signer),
      ),
    ).toEqual('0');

    expect(
      await recommendProcessingFee(
        taikoChain,
        mainnetChain,
        ProcessingFeeMethod.RECOMMENDED,
        null,
        get(signer),
      ),
    ).toEqual('0');

    expect(
      await recommendProcessingFee(
        taikoChain,
        mainnetChain,
        ProcessingFeeMethod.RECOMMENDED,
        ETHToken,
        null,
      ),
    ).toEqual('0');
  });

  it('uses ethGasLimit if the token is ETH', async () => {
    const fee = await recommendProcessingFee(
      taikoChain,
      mainnetChain,
      ProcessingFeeMethod.RECOMMENDED,
      ETHToken,
      mockSigner,
    );

    const expected = ethers.utils.formatEther(
      BigNumber.from(gasPrice).mul(ethGasLimit),
    );

    expect(fee).toStrictEqual(expected);
  });

  it('uses erc20NotDeployedGasLimit if the token is not ETH and token is not deployed on dest layer', async () => {
    mockContract.canonicalToBridged.mockImplementationOnce(
      () => ethers.constants.AddressZero,
    );

    const fee = await recommendProcessingFee(
      taikoChain,
      mainnetChain,
      ProcessingFeeMethod.RECOMMENDED,
      testERC20Tokens[0],
      mockSigner,
    );

    const expected = ethers.utils.formatEther(
      BigNumber.from(gasPrice).mul(erc20NotDeployedGasLimit),
    );

    expect(fee).toStrictEqual(expected);
  });

  it('uses erc20DeployedGasLimit if the token is not ETH and token is already deployed on dest layer', async () => {
    mockContract.canonicalToBridged.mockImplementationOnce(() => '0x123');

    const fee = await recommendProcessingFee(
      taikoChain,
      mainnetChain,
      ProcessingFeeMethod.RECOMMENDED,
      testERC20Tokens[0],
      mockSigner,
    );

    const expected = ethers.utils.formatEther(
      BigNumber.from(gasPrice).mul(erc20DeployedGasLimit),
    );

    expect(fee).toStrictEqual(expected);
  });

  it('uses destination token address', async () => {
    await recommendProcessingFee(
      taikoChain,
      mainnetChain,
      ProcessingFeeMethod.RECOMMENDED,
      mockToken,
      mockSigner,
    );

    expect(mockContract.canonicalToBridged).toHaveBeenCalledWith(
      taikoChain.id,
      mockToken.addresses[L2_CHAIN_ID],
    );
  });

  it('throws on canonicalToBridged call', async () => {
    mockContract.canonicalToBridged.mockRejectedValue(new Error('BAM!!'));

    await expect(
      recommendProcessingFee(
        taikoChain,
        mainnetChain,
        ProcessingFeeMethod.RECOMMENDED,
        testERC20Tokens[0],
        mockSigner,
      ),
    ).rejects.toThrowError('failed to get bridged address');
  });
});

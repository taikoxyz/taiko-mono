import { BigNumber, ethers, Signer } from 'ethers';
import { get } from 'svelte/store';
import { ProcessingFeeMethod } from '../domain/fee';
import { signer } from '../store/signer';
import {
  erc20DeployedGasLimit,
  erc20NotDeployedGasLimit,
  ethGasLimit,
  recommendProcessingFee,
} from './recommendProcessingFee';
import { mainnetChain, taikoChain } from '../chain/chains';
import { ETHToken, testERC20Tokens } from '../token/tokens';
import { providers } from '../provider/providers';

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
    ).toStrictEqual('0');

    expect(
      await recommendProcessingFee(
        mainnetChain,
        null,
        ProcessingFeeMethod.RECOMMENDED,
        ETHToken,
        get(signer),
      ),
    ).toStrictEqual('0');

    expect(
      await recommendProcessingFee(
        mainnetChain,
        taikoChain,
        null,
        ETHToken,
        get(signer),
      ),
    ).toStrictEqual('0');

    expect(
      await recommendProcessingFee(
        taikoChain,
        mainnetChain,
        ProcessingFeeMethod.RECOMMENDED,
        null,
        get(signer),
      ),
    ).toStrictEqual('0');

    expect(
      await recommendProcessingFee(
        taikoChain,
        mainnetChain,
        ProcessingFeeMethod.RECOMMENDED,
        ETHToken,
        null,
      ),
    ).toStrictEqual('0');
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

  it('uses erc20NotDeployedGasLimit if the token is not ETH and token is not deployed on dest layer', async () => {
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
});

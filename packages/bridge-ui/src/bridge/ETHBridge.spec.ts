import { BigNumber, ethers, Wallet } from 'ethers';

import { L1_CHAIN_ID, L2_CHAIN_ID } from '../constants/envVars';
import type { Bridge, BridgeOpts } from '../domain/bridge';
import { Message, MessageStatus } from '../domain/message';
import { ETHBridge } from './ETHBridge';

jest.mock('../constants/envVars');

const mockSigner = {
  getAddress: jest.fn(),
};

const mockContract = {
  sendEther: jest.fn(),
  sendMessage: jest.fn(),
  getMessageStatus: jest.fn(),
  processMessage: jest.fn(),
  retryMessage: jest.fn(),
  releaseEther: jest.fn(),
};

const mockProver = {
  generateProof: jest.fn(),
  generateReleaseProof: jest.fn(),
};

jest.mock('ethers', () => ({
  /* eslint-disable-next-line */
  ...(jest.requireActual('ethers') as object),
  Wallet: function () {
    return mockSigner;
  },
  Signer: function () {
    return mockSigner;
  },
  Contract: function () {
    return mockContract;
  },
  providers: {
    JsonRpcProvider: jest.fn(),
  },
}));

describe('bridge tests', () => {
  beforeEach(() => {
    jest.resetAllMocks();
  });

  it('requires allowance returns false', async () => {
    const bridge: Bridge = new ETHBridge(null);

    const requires = await bridge.requiresAllowance({
      amount: BigNumber.from(1),
      signer: new Wallet('0x'),
      contractAddress: '0x1234',
      spenderAddress: '0x',
    });
    expect(requires).toBe(false);
  });

  it('approve returns empty transaction', async () => {
    const bridge: Bridge = new ETHBridge(null);

    const tx = await bridge.approve({
      amount: BigNumber.from(1),
      signer: new Wallet('0x'),
      contractAddress: '0x1234',
      spenderAddress: '0x',
    });

    expect(tx).toEqual({});
  });

  it('bridges with processing fee, owner !== to', async () => {
    const bridge: Bridge = new ETHBridge(null);
    const wallet = new Wallet('0x');

    mockSigner.getAddress.mockImplementationOnce(() => {
      return '0xfake';
    });

    const opts: BridgeOpts = {
      amount: BigNumber.from(1),
      signer: wallet,
      tokenAddress: '',
      srcChainId: L1_CHAIN_ID,
      destChainId: L2_CHAIN_ID,
      tokenVaultAddress: '0x456',
      bridgeAddress: '0x456',
      processingFeeInWei: BigNumber.from(2),
      memo: 'memo',
      to: '0x',
    };

    expect(mockSigner.getAddress).not.toHaveBeenCalled();
    await bridge.bridge(opts);

    expect(mockSigner.getAddress).toHaveBeenCalled();
    expect(mockContract.sendMessage).toHaveBeenCalledWith(
      {
        callValue: BigNumber.from('0x01'), // callValue !== 0 because message owner is NOT the same as recipient
        data: '0x',
        depositValue: BigNumber.from('0x00'),
        destChainId: 167001,
        gasLimit: BigNumber.from('0x0222e0'),
        id: 1,
        memo: 'memo',
        owner: '0xfake',
        processingFee: BigNumber.from('0x02'),
        refundAddress: '0xfake',
        sender: '0xfake',
        srcChainId: 31336,
        to: '0x',
      },
      { value: BigNumber.from('0x03') },
    );
  });

  it('bridges without processing fee, owner === to', async () => {
    const bridge: Bridge = new ETHBridge(null);

    const wallet = new Wallet('0x');
    mockSigner.getAddress.mockImplementation(() => {
      return '0xfake';
    });

    const opts: BridgeOpts = {
      amount: BigNumber.from(1),
      signer: wallet,
      tokenAddress: '',
      srcChainId: L1_CHAIN_ID,
      destChainId: L2_CHAIN_ID,
      tokenVaultAddress: '0x456',
      bridgeAddress: '0x456',
      to: await wallet.getAddress(),
    };

    await bridge.bridge(opts);
    expect(mockContract.sendMessage).toHaveBeenCalledWith(
      {
        callValue: BigNumber.from('0x00'), // callValue == 0 because message owner is same as recipient
        data: '0x',
        depositValue: BigNumber.from('0x01'),
        destChainId: 167001,
        gasLimit: BigNumber.from('0x00'),
        id: 1,
        memo: '',
        owner: '0xfake',
        processingFee: BigNumber.from('0x00'),
        refundAddress: '0xfake',
        sender: '0xfake',
        srcChainId: 31336,
        to: '0xfake',
      },
      { value: BigNumber.from('0x01') },
    );
  });

  it('claim throws if message status is done', async () => {
    mockContract.getMessageStatus.mockImplementationOnce(() => {
      return MessageStatus.Done;
    });

    const wallet = new Wallet('0x');

    const bridge: Bridge = new ETHBridge(null);

    await expect(
      bridge.claim({
        message: {
          srcChainId: BigNumber.from(L2_CHAIN_ID),
          destChainId: BigNumber.from(L1_CHAIN_ID),
          gasLimit: BigNumber.from(1),
        } as unknown as Message,
        msgHash: '0x',
        srcBridgeAddress: '0x',
        destBridgeAddress: '0x',
        signer: wallet,
      }),
    ).rejects.toThrowError('message already processed');
  });

  it('claim throws if message owner is not signer', async () => {
    mockContract.getMessageStatus.mockImplementationOnce(() => {
      return MessageStatus.New;
    });

    mockSigner.getAddress.mockImplementationOnce(() => {
      return '0xfake';
    });

    const wallet = new Wallet('0x');

    const bridge: Bridge = new ETHBridge(null);

    await expect(
      bridge.claim({
        message: {
          owner: '0x',
          srcChainId: BigNumber.from(L2_CHAIN_ID),
          destChainId: BigNumber.from(L1_CHAIN_ID),
          gasLimit: BigNumber.from(1),
        } as unknown as Message,
        msgHash: '0x',
        srcBridgeAddress: '0x',
        destBridgeAddress: '0x',
        signer: wallet,
      }),
    ).rejects.toThrowError(
      'user can not process this, it is not their message',
    );
  });

  it('claim processMessage', async () => {
    mockContract.getMessageStatus.mockImplementationOnce(() => {
      return MessageStatus.New;
    });

    mockSigner.getAddress.mockImplementationOnce(() => {
      return '0x';
    });

    const wallet = new Wallet('0x');

    const bridge: Bridge = new ETHBridge(mockProver);

    expect(mockContract.processMessage).not.toHaveBeenCalled();

    expect(mockProver.generateProof).not.toHaveBeenCalled();

    await bridge.claim({
      message: {
        owner: '0x',
        srcChainId: BigNumber.from(L2_CHAIN_ID),
        destChainId: BigNumber.from(L1_CHAIN_ID),
        sender: '0x01',
        gasLimit: BigNumber.from(1),
      } as unknown as Message,
      msgHash: '0x',
      srcBridgeAddress: '0x',
      destBridgeAddress: '0x',
      signer: wallet,
    });

    expect(mockProver.generateProof).toHaveBeenCalled();

    expect(mockContract.processMessage).toHaveBeenCalled();
  });

  it('claim retryMessage', async () => {
    mockContract.getMessageStatus.mockImplementationOnce(() => {
      return MessageStatus.Retriable;
    });

    mockSigner.getAddress.mockImplementationOnce(() => {
      return '0x';
    });

    const wallet = new Wallet('0x');

    const bridge: Bridge = new ETHBridge(mockProver);

    expect(mockContract.retryMessage).not.toHaveBeenCalled();

    expect(mockProver.generateProof).not.toHaveBeenCalled();

    await bridge.claim({
      message: {
        owner: '0x',
        srcChainId: BigNumber.from(L2_CHAIN_ID),
        destChainId: BigNumber.from(L1_CHAIN_ID),
        sender: '0x01',
        gasLimit: BigNumber.from(1),
      } as unknown as Message,
      msgHash: '0x',
      srcBridgeAddress: '0x',
      destBridgeAddress: '0x',
      signer: wallet,
    });

    expect(mockProver.generateProof).not.toHaveBeenCalled();

    expect(mockContract.retryMessage).toHaveBeenCalled();
  });

  it('release tokens throws if message is already in DONE status', async () => {
    mockContract.getMessageStatus.mockImplementationOnce(() => {
      return MessageStatus.Done;
    });

    mockSigner.getAddress.mockImplementationOnce(() => {
      return '0x';
    });

    const wallet = new Wallet('0x');

    const bridge: Bridge = new ETHBridge(mockProver);

    expect(mockContract.releaseEther).not.toHaveBeenCalled();

    expect(mockProver.generateReleaseProof).not.toHaveBeenCalled();

    await expect(
      bridge.release({
        message: {
          owner: '0x',
          srcChainId: BigNumber.from(L2_CHAIN_ID),
          destChainId: BigNumber.from(L1_CHAIN_ID),
          sender: '0x01',
          gasLimit: BigNumber.from(1),
        } as unknown as Message,
        msgHash: '0x',
        srcBridgeAddress: '0x',
        destBridgeAddress: '0x',
        signer: wallet,
        destProvider: new ethers.providers.StaticJsonRpcProvider(),
        srcTokenVaultAddress: '0x',
      }),
    ).rejects.toThrowError('message already processed');
  });

  it('release tokens', async () => {
    mockContract.getMessageStatus.mockImplementationOnce(() => {
      return MessageStatus.Failed;
    });

    mockSigner.getAddress.mockImplementationOnce(() => {
      return '0x';
    });

    const wallet = new Wallet('0x');

    const bridge: Bridge = new ETHBridge(mockProver);

    expect(mockContract.releaseEther).not.toHaveBeenCalled();

    expect(mockProver.generateReleaseProof).not.toHaveBeenCalled();

    await bridge.release({
      message: {
        owner: '0x',
        srcChainId: BigNumber.from(L2_CHAIN_ID),
        destChainId: BigNumber.from(L1_CHAIN_ID),
        sender: '0x01',
        gasLimit: BigNumber.from(1),
      } as unknown as Message,
      msgHash: '0x',
      srcBridgeAddress: '0x',
      destBridgeAddress: '0x',
      signer: wallet,
      destProvider: new ethers.providers.StaticJsonRpcProvider(),
      srcTokenVaultAddress: '0x',
    });

    expect(mockProver.generateReleaseProof).toHaveBeenCalled();

    expect(mockContract.releaseEther).toHaveBeenCalled();
  });
});

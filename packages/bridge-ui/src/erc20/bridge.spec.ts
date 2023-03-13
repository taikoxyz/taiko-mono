import { BigNumber, ethers, Wallet } from 'ethers';
import {
  CHAIN_ID_MAINNET,
  CHAIN_ID_TAIKO,
  mainnet,
  taiko,
} from '../domain/chain';
import type { ApproveOpts, Bridge, BridgeOpts } from '../domain/bridge';
import ERC20Bridge from './bridge';
import { Message, MessageStatus } from '../domain/message';

const mockSigner = {
  getAddress: jest.fn(),
};

const mockContract = {
  sendERC20: jest.fn(),
  allowance: jest.fn(),
  approve: jest.fn(),
  processMessage: jest.fn(),
  retryMessage: jest.fn(),
  getMessageStatus: jest.fn(),
  releaseERC20: jest.fn(),
};

const mockProver = {
  GenerateProof: jest.fn(),
  GenerateReleaseProof: jest.fn(),
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
}));

const wallet = new Wallet('0x');

const opts: BridgeOpts = {
  amountInWei: BigNumber.from(1),
  signer: wallet,
  tokenAddress: '0xtoken',
  fromChainId: mainnet.id,
  toChainId: taiko.id,
  tokenVaultAddress: '0x456',
  processingFeeInWei: BigNumber.from(2),
  memo: 'memo',
  to: '0x',
};

const approveOpts: ApproveOpts = {
  amountInWei: BigNumber.from(1),
  signer: wallet,
  contractAddress: '0x456',
  spenderAddress: '0x789',
};

describe('bridge tests', () => {
  beforeEach(() => {
    jest.resetAllMocks();
  });

  it('requires allowance returns true when allowance has not been set', async () => {
    mockContract.allowance.mockImplementationOnce(() =>
      opts.amountInWei.sub(1),
    );

    mockSigner.getAddress.mockImplementationOnce(() => '0xfake');

    const bridge: Bridge = new ERC20Bridge(null);

    expect(mockContract.allowance).not.toHaveBeenCalled();
    const requires = await bridge.RequiresAllowance(approveOpts);

    expect(mockSigner.getAddress).toHaveBeenCalled();
    expect(mockContract.allowance).toHaveBeenCalledWith(
      '0xfake',
      approveOpts.spenderAddress,
    );
    expect(requires).toBe(true);
  });

  it('requires allowance returns true when allowance is > than amount', async () => {
    mockContract.allowance.mockImplementationOnce(() =>
      opts.amountInWei.add(1),
    );
    mockSigner.getAddress.mockImplementationOnce(() => '0xfake');

    const bridge: Bridge = new ERC20Bridge(null);

    expect(mockContract.allowance).not.toHaveBeenCalled();
    const requires = await bridge.RequiresAllowance(approveOpts);

    expect(mockSigner.getAddress).toHaveBeenCalled();
    expect(mockContract.allowance).toHaveBeenCalledWith(
      '0xfake',
      approveOpts.spenderAddress,
    );
    expect(requires).toBe(false);
  });

  it('requires allowance returns true when allowance is === amount', async () => {
    mockContract.allowance.mockImplementationOnce(() => opts.amountInWei);
    mockSigner.getAddress.mockImplementationOnce(() => '0xfake');

    const bridge: Bridge = new ERC20Bridge(null);

    expect(mockContract.allowance).not.toHaveBeenCalled();
    const requires = await bridge.RequiresAllowance(approveOpts);

    expect(mockSigner.getAddress).toHaveBeenCalled();
    expect(mockContract.allowance).toHaveBeenCalledWith(
      '0xfake',
      approveOpts.spenderAddress,
    );
    expect(requires).toBe(false);
  });

  it('approve throws when amount is already greater than whats set', async () => {
    mockContract.allowance.mockImplementationOnce(() =>
      opts.amountInWei.add(1),
    );

    mockSigner.getAddress.mockImplementationOnce(() => '0xfake');

    const bridge: Bridge = new ERC20Bridge(null);

    expect(mockContract.allowance).not.toHaveBeenCalled();
    await expect(bridge.Approve(approveOpts)).rejects.toThrowError(
      'token vault already has required allowance',
    );

    expect(mockSigner.getAddress).toHaveBeenCalled();
    expect(mockContract.allowance).toHaveBeenCalledWith(
      '0xfake',
      approveOpts.spenderAddress,
    );
  });

  it('approve succeeds when allowance is less than what is being requested', async () => {
    mockContract.allowance.mockImplementationOnce(() =>
      opts.amountInWei.sub(1),
    );

    mockSigner.getAddress.mockImplementationOnce(() => '0xfake');

    const bridge: Bridge = new ERC20Bridge(null);

    expect(mockContract.allowance).not.toHaveBeenCalled();
    await bridge.Approve(approveOpts);

    expect(mockSigner.getAddress).toHaveBeenCalled();
    expect(mockContract.allowance).toHaveBeenCalledWith(
      '0xfake',
      approveOpts.spenderAddress,
    );
    expect(mockContract.approve).toHaveBeenCalledWith(
      approveOpts.spenderAddress,
      approveOpts.amountInWei,
    );
  });

  it('bridge throws when requires approval', async () => {
    mockContract.allowance.mockImplementationOnce(() =>
      opts.amountInWei.sub(1),
    );

    const bridge: Bridge = new ERC20Bridge(null);

    expect(mockContract.sendERC20).not.toHaveBeenCalled();

    await expect(bridge.Bridge(opts)).rejects.toThrowError(
      'token vault does not have required allowance',
    );

    expect(mockContract.sendERC20).not.toHaveBeenCalled();
  });

  it('bridge calls senderc20 when doesnt require approval', async () => {
    mockContract.allowance.mockImplementationOnce(() =>
      opts.amountInWei.add(1),
    );
    mockSigner.getAddress.mockImplementation(() => '0xfake');

    const bridge: Bridge = new ERC20Bridge(null);

    expect(mockContract.sendERC20).not.toHaveBeenCalled();

    await bridge.Bridge(opts);

    expect(mockContract.sendERC20).toHaveBeenCalled();
    expect(mockContract.sendERC20).toHaveBeenCalledWith(
      opts.toChainId,
      '0x',
      opts.tokenAddress,
      opts.amountInWei,
      BigNumber.from(2640000),
      opts.processingFeeInWei,
      '0xfake',
      opts.memo,
      {
        value: opts.processingFeeInWei,
      },
    );
  });

  it('bridge calls senderc20 when doesnt requires approval, with no processing fee and memo', async () => {
    mockContract.allowance.mockImplementationOnce(() =>
      opts.amountInWei.add(1),
    );
    mockSigner.getAddress.mockImplementation(() => '0xfake');

    const bridge: Bridge = new ERC20Bridge(null);

    expect(mockContract.sendERC20).not.toHaveBeenCalled();

    const opts: BridgeOpts = {
      amountInWei: BigNumber.from(1),
      signer: wallet,
      tokenAddress: '0xtoken',
      fromChainId: mainnet.id,
      toChainId: taiko.id,
      tokenVaultAddress: '0x456',
      to: await wallet.getAddress(),
    };

    await bridge.Bridge(opts);

    expect(mockContract.sendERC20).toHaveBeenCalledWith(
      opts.toChainId,
      '0xfake',
      opts.tokenAddress,
      opts.amountInWei,
      BigNumber.from(2500000),
      BigNumber.from(0),
      '0xfake',
      '',
      {
        value: BigNumber.from(0),
      },
    );
  });

  it('claim throws if message status is done', async () => {
    mockContract.getMessageStatus.mockImplementationOnce(() => {
      return MessageStatus.Done;
    });

    const wallet = new Wallet('0x');

    const bridge: Bridge = new ERC20Bridge(null);

    await expect(
      bridge.Claim({
        message: {
          srcChainId: BigNumber.from(CHAIN_ID_TAIKO),
          destChainId: BigNumber.from(CHAIN_ID_MAINNET),
          gasLimit: BigNumber.from(1),
        } as unknown as Message,
        msgHash: '0x',
        srcBridgeAddress: '0x',
        destBridgeAddress: '0x',
        signer: wallet,
      }),
    ).rejects.toThrowError('message already processed');
  });

  it('claim throws if message status is failed', async () => {
    mockContract.getMessageStatus.mockImplementationOnce(() => {
      return MessageStatus.Failed;
    });

    const wallet = new Wallet('0x');

    const bridge: Bridge = new ERC20Bridge(null);

    await expect(
      bridge.Claim({
        message: {
          srcChainId: BigNumber.from(CHAIN_ID_TAIKO),
          destChainId: BigNumber.from(CHAIN_ID_MAINNET),
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

    const bridge: Bridge = new ERC20Bridge(null);

    await expect(
      bridge.Claim({
        message: {
          owner: '0x',
          srcChainId: BigNumber.from(CHAIN_ID_TAIKO),
          destChainId: BigNumber.from(CHAIN_ID_MAINNET),
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

    const bridge: Bridge = new ERC20Bridge(mockProver);

    expect(mockContract.processMessage).not.toHaveBeenCalled();

    expect(mockProver.GenerateProof).not.toHaveBeenCalled();

    await bridge.Claim({
      message: {
        owner: '0x',
        srcChainId: BigNumber.from(CHAIN_ID_TAIKO),
        destChainId: BigNumber.from(CHAIN_ID_MAINNET),
        sender: '0x01',
        gasLimit: BigNumber.from(1),
      } as unknown as Message,
      msgHash: '0x',
      srcBridgeAddress: '0x',
      destBridgeAddress: '0x',
      signer: wallet,
    });

    expect(mockProver.GenerateProof).toHaveBeenCalled();

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

    const bridge: Bridge = new ERC20Bridge(mockProver);

    expect(mockContract.retryMessage).not.toHaveBeenCalled();

    expect(mockProver.GenerateProof).not.toHaveBeenCalled();

    await bridge.Claim({
      message: {
        owner: '0x',
        srcChainId: BigNumber.from(CHAIN_ID_TAIKO),
        destChainId: BigNumber.from(CHAIN_ID_MAINNET),
        sender: '0x01',
        gasLimit: BigNumber.from(1),
      } as unknown as Message,
      msgHash: '0x',
      srcBridgeAddress: '0x',
      destBridgeAddress: '0x',
      signer: wallet,
    });

    expect(mockProver.GenerateProof).not.toHaveBeenCalled();

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

    const bridge: Bridge = new ERC20Bridge(mockProver);

    expect(mockContract.releaseERC20).not.toHaveBeenCalled();

    expect(mockProver.GenerateReleaseProof).not.toHaveBeenCalled();

    await expect(
      bridge.ReleaseTokens({
        message: {
          owner: '0x',
          srcChainId: BigNumber.from(CHAIN_ID_TAIKO),
          destChainId: BigNumber.from(CHAIN_ID_MAINNET),
          sender: '0x01',
          gasLimit: BigNumber.from(1),
        } as unknown as Message,
        msgHash: '0x',
        srcBridgeAddress: '0x',
        destBridgeAddress: '0x',
        signer: wallet,
        destProvider: new ethers.providers.JsonRpcProvider(),
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

    const bridge: Bridge = new ERC20Bridge(mockProver);

    expect(mockContract.releaseERC20).not.toHaveBeenCalled();

    expect(mockProver.GenerateReleaseProof).not.toHaveBeenCalled();

    await bridge.ReleaseTokens({
      message: {
        owner: '0x',
        srcChainId: BigNumber.from(CHAIN_ID_TAIKO),
        destChainId: BigNumber.from(CHAIN_ID_MAINNET),
        sender: '0x01',
        gasLimit: BigNumber.from(1),
      } as unknown as Message,
      msgHash: '0x',
      srcBridgeAddress: '0x',
      destBridgeAddress: '0x',
      signer: wallet,
      destProvider: new ethers.providers.JsonRpcProvider(),
      srcTokenVaultAddress: '0x',
    });

    expect(mockProver.GenerateReleaseProof).toHaveBeenCalled();

    expect(mockContract.releaseERC20).toHaveBeenCalled();
  });
});

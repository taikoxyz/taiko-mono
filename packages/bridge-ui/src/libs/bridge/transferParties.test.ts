/**
 * "Sender" and "recipient" mean the user's addresses, not the message envelope's. A token
 * transfer is a message from the source vault to the destination vault, with the owner and
 * the recipient carried inside the payload; showing the envelope put two bridge contracts
 * where the user expected their own addresses, and let a self-transfer look like one to a
 * stranger.
 */
import { type Address, encodeAbiParameters, encodeFunctionData } from 'viem';

import { TokenType } from '$libs/token';
import { ALICE, BOB, L1_ADDRESSES, L2_A_ADDRESSES } from '$mocks';

import { getTransferParties } from './transferParties';
import {
  erc20InvocationParameters,
  erc721InvocationParameters,
  erc1155InvocationParameters,
  onMessageInvocationAbi,
} from './vaultInvocation';

const CANONICAL = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48' as Address;

const vaultPayload = (encoded: `0x${string}`) =>
  encodeFunctionData({ abi: onMessageInvocationAbi, functionName: 'onMessageInvocation', args: [encoded] });

const message = (overrides: Record<string, unknown>) => ({
  id: 1n,
  from: ALICE,
  srcChainId: 1n,
  destChainId: 2n,
  srcOwner: ALICE,
  destOwner: ALICE,
  to: ALICE,
  value: 0n,
  fee: 0n,
  gasLimit: 1,
  data: '0x',
  ...overrides,
});

describe('getTransferParties', () => {
  it('reads an ETH transfer straight off the envelope', () => {
    const tx = { tokenType: TokenType.ETH, from: ALICE, message: message({ to: BOB, value: 5n }) } as never;

    expect(getTransferParties(tx)).toEqual({ sender: ALICE, recipient: BOB });
  });

  it('names the token owner and the payload recipient for an ERC20 transfer, not the vaults', () => {
    const erc20 = { chainId: 1n, addr: CANONICAL, decimals: 6, symbol: 'USDC', name: 'USD Coin' };
    const data = vaultPayload(encodeAbiParameters(erc20InvocationParameters, [erc20, ALICE, BOB, 100n]));
    const tx = {
      tokenType: TokenType.ERC20,
      from: ALICE,
      message: message({ from: L1_ADDRESSES.erc20VaultAddress, to: L2_A_ADDRESSES.erc20VaultAddress, data }),
    } as never;

    expect(getTransferParties(tx)).toEqual({ sender: ALICE, recipient: BOB });
  });

  it('does the same for an ERC721 transfer', () => {
    const nft = { chainId: 1n, addr: CANONICAL, symbol: 'NFT', name: 'Some NFT' };
    const data = vaultPayload(encodeAbiParameters(erc721InvocationParameters, [nft, ALICE, BOB, [7n]]));
    const tx = {
      tokenType: TokenType.ERC721,
      from: ALICE,
      message: message({ from: L1_ADDRESSES.erc721VaultAddress, to: L2_A_ADDRESSES.erc721VaultAddress, data }),
    } as never;

    expect(getTransferParties(tx)).toEqual({ sender: ALICE, recipient: BOB });
  });

  it('does the same for an ERC1155 transfer', () => {
    const nft = { chainId: 1n, addr: CANONICAL, symbol: 'NFT', name: 'Some NFT' };
    const data = vaultPayload(encodeAbiParameters(erc1155InvocationParameters, [nft, ALICE, BOB, [7n], [2n]]));
    const tx = {
      tokenType: TokenType.ERC1155,
      from: ALICE,
      message: message({ from: L1_ADDRESSES.erc1155VaultAddress, to: L2_A_ADDRESSES.erc1155VaultAddress, data }),
    } as never;

    expect(getTransferParties(tx)).toEqual({ sender: ALICE, recipient: BOB });
  });

  it('shows no recipient rather than a vault when the payload cannot be read', () => {
    const tx = {
      tokenType: TokenType.ERC20,
      from: ALICE,
      message: message({ from: L1_ADDRESSES.erc20VaultAddress, to: L2_A_ADDRESSES.erc20VaultAddress, data: '0xdead' }),
    } as never;

    expect(getTransferParties(tx)).toEqual({ sender: ALICE, recipient: null });
  });

  it('falls back to the recorded sender for a row that has no message yet', () => {
    // A locally recorded transaction only gains its message once the receipt log is read
    const tx = { tokenType: TokenType.ERC20, from: ALICE } as never;

    expect(getTransferParties(tx)).toEqual({ sender: ALICE, recipient: null });
  });
});

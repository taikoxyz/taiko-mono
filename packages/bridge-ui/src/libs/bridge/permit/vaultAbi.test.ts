/**
 * The permit entrypoints were added to the generated vault ABI by hand, from the Solidity
 * source, because regenerating it needs a Foundry build. What a hand edit can get wrong - a
 * tuple field out of order, a type off by a width - changes the selector, so each entry is
 * pinned to the signature the contract declares. `sendToken`'s selector is the one the
 * relayer's binding hardcodes, and it shares the struct with the two new entrypoints.
 */
import { type Abi, type AbiFunction, toFunctionSelector } from 'viem';

import { erc20VaultAbi } from '$abi';

const BRIDGE_TRANSFER_OP = '(uint64,address,address,uint64,address,uint32,uint256)';

/** The vault ABI entry of that name; a plain lookup, since the names under test are data here */
const entryNamed = (name: string) => {
  const entry = (erc20VaultAbi as Abi).find((item) => 'name' in item && item.name === name);
  if (!entry) throw new Error(`the vault ABI has no ${name}`);
  return entry;
};

const selectorOf = (name: string) => toFunctionSelector(entryNamed(name) as AbiFunction);

describe('the hand-inserted ERC20Vault ABI entries', () => {
  it('encode the entrypoints as the contract declares them', () => {
    expect(selectorOf('sendToken')).toBe(toFunctionSelector(`sendToken(${BRIDGE_TRANSFER_OP})`));
    expect(selectorOf('sendToken')).toBe('0xb84d9ffe');
    expect(selectorOf('sendTokenWithPermit')).toBe(
      toFunctionSelector(`sendTokenWithPermit(${BRIDGE_TRANSFER_OP},uint256,uint8,bytes32,bytes32)`),
    );
    expect(selectorOf('sendTokenWithPermit2')).toBe(
      toFunctionSelector(`sendTokenWithPermit2(${BRIDGE_TRANSFER_OP},uint256,uint256,bytes)`),
    );
    expect(selectorOf('PERMIT2')).toBe(toFunctionSelector('PERMIT2()'));
  });

  it('return the bridge message like sendToken does', () => {
    const outputsOf = (name: string) => JSON.stringify((entryNamed(name) as AbiFunction).outputs);

    expect(outputsOf('sendTokenWithPermit')).toBe(outputsOf('sendToken'));
    expect(outputsOf('sendTokenWithPermit2')).toBe(outputsOf('sendToken'));
  });

  it('name the error the vault raises when a permit leaves no allowance', () => {
    expect(entryNamed('VAULT_PERMIT_NO_ALLOWANCE')).toMatchObject({ type: 'error' });
  });
});

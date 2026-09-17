/**
 * A signed flow is ruled out for a token only on a verdict about the flow itself. Anything a
 * retry may fix - an unreachable RPC, a revert unrelated to the permit, missing gas money -
 * leaves it open, or one bad moment would cost the user an approval for the session.
 */
import {
  type Abi,
  BaseError,
  ContractFunctionExecutionError,
  ContractFunctionRevertedError,
  encodeErrorResult,
  HttpRequestError,
  MethodNotSupportedRpcError,
  UserRejectedRequestError,
} from 'viem';

import { erc20VaultAbi } from '$abi';

import { permit2SignatureErrorsAbi } from './abi';
import { isUserRejection, permitFlowsRuledOutBy } from './sendFailure';
import { TypedDataSigningError } from './signatures';

/** How viem reports a failed send: its wrapper around whatever happened underneath */
const failedWith = (cause: BaseError) =>
  new ContractFunctionExecutionError(cause, { abi: [], functionName: 'sendTokenWithPermit' });

/** A revert the ABI the call was made with can name */
const revertedWith = (abi: Abi, errorName: string) =>
  failedWith(
    new ContractFunctionRevertedError({ abi, data: encodeErrorResult({ abi, errorName }), functionName: 'send' }),
  );

const transportFailure = () =>
  failedWith(new HttpRequestError({ url: 'https://l1.rpc', details: 'fetch failed', body: {} }));

describe('permitFlowsRuledOutBy', () => {
  it('rules the permit flow out when the vault found no allowance behind the signature', () => {
    const error = revertedWith(erc20VaultAbi, 'VAULT_PERMIT_NO_ALLOWANCE');

    expect(permitFlowsRuledOutBy(error, 'permit')).toEqual(['permit']);
    // Not a verdict on Permit2, whichever way it is reached
    expect(permitFlowsRuledOutBy(error, 'permit2')).toEqual([]);
  });

  it('rules the Permit2 flow out when Permit2 refuses the signature', () => {
    for (const errorName of [
      'InvalidSigner',
      'InvalidSignature',
      'InvalidSignatureLength',
      'InvalidContractSignature',
    ]) {
      const error = revertedWith(permit2SignatureErrorsAbi, errorName);
      expect(permitFlowsRuledOutBy(error, 'permit2')).toEqual(['permit2']);
      expect(permitFlowsRuledOutBy(error, 'permit')).toEqual([]);
    }
  });

  it('rules both out for a wallet that cannot sign typed data', () => {
    const unsupported = new MethodNotSupportedRpcError(new Error('eth_signTypedData_v4 is not available'));

    expect(permitFlowsRuledOutBy(new TypedDataSigningError(unsupported), 'permit')).toEqual(['permit', 'permit2']);
    // The same answer from anything but the signing step says nothing about signing
    expect(permitFlowsRuledOutBy(unsupported, 'permit')).toEqual([]);
    expect(permitFlowsRuledOutBy(failedWith(unsupported), 'permit2')).toEqual([]);
  });

  it('does not read a declined signature prompt as an unsupported wallet', () => {
    const declined = new TypedDataSigningError(new UserRejectedRequestError(new Error('User rejected the request.')));

    expect(isUserRejection(declined)).toBe(true);
    expect(permitFlowsRuledOutBy(declined, 'permit2')).toEqual([]);
  });

  it('keeps the flow open on anything a retry may fix', () => {
    // An unrelated vault revert: a plain send fails on it too
    expect(permitFlowsRuledOutBy(revertedWith(erc20VaultAbi, 'VAULT_INVALID_TO_ADDR'), 'permit')).toEqual([]);
    expect(permitFlowsRuledOutBy(revertedWith(erc20VaultAbi, 'VAULT_INSUFFICIENT_FEE'), 'permit2')).toEqual([]);
    // The RPC, not the chain
    expect(permitFlowsRuledOutBy(transportFailure(), 'permit')).toEqual([]);
    // A revert the ABI cannot name says nothing about the flow either
    const unknownRevert = failedWith(
      new ContractFunctionRevertedError({ abi: [], data: '0xcd21db4f', functionName: 'send' }),
    );
    expect(permitFlowsRuledOutBy(unknownRevert, 'permit2')).toEqual([]);
    // Nor does something that is not a viem error at all
    expect(permitFlowsRuledOutBy(new Error('boom'), 'permit')).toEqual([]);
  });

  it('never rules a flow out over a declined prompt', () => {
    expect(
      permitFlowsRuledOutBy(new UserRejectedRequestError(new Error('User rejected the request.')), 'permit'),
    ).toEqual([]);
  });
});

describe('isUserRejection', () => {
  it('finds the rejection viem mapped, however deep it is wrapped', () => {
    expect(isUserRejection(failedWith(new UserRejectedRequestError(new Error('no'))))).toBe(true);
  });

  it("recognises a wallet's own wording", () => {
    expect(isUserRejection(new Error('MetaMask Tx Signature: User denied transaction signature.'))).toBe(true);
    expect(isUserRejection(new Error('MetaMask Typed Message Signature: User denied message signature.'))).toBe(true);
    expect(isUserRejection(new Error('User rejected the request.'))).toBe(true);
  });

  it('does not mistake other failures for one', () => {
    expect(isUserRejection(transportFailure())).toBe(false);
    expect(isUserRejection(new Error('insufficient funds for gas'))).toBe(false);
  });
});

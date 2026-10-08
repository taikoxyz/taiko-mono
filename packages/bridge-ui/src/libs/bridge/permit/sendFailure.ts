import {
  type BaseError,
  ChainDisconnectedError,
  ContractFunctionRevertedError,
  ProviderDisconnectedError,
  UserRejectedRequestError,
} from 'viem';

import type { PermitMethod } from './capabilities';
import { TypedDataSigningError } from './signatures';

/** The vault's verdict that the token's `permit` left no allowance behind */
const VAULT_PERMIT_REJECTED = 'VAULT_PERMIT_NO_ALLOWANCE';

/** Permit2's verdicts on the signature itself, as named in permit2SignatureErrorsAbi */
const PERMIT2_SIGNATURE_REJECTED = new Set([
  'InvalidSignatureLength',
  'InvalidSignature',
  'InvalidSigner',
  'InvalidContractSignature',
]);

/**
 * @dev The first error in a cause chain that satisfies the predicate, if any. viem wraps what
 *      a wallet, a node or a contract said in layers of its own, and the signing step wraps
 *      once more; the verdict is inside. Walked by hand so that it works for any Error with a
 *      `cause`, not only viem's, and bounded in case a chain loops.
 * @param error What a wallet round trip rejected with
 * @param match The kind of cause looked for
 * @return cause_ The matching cause, or null
 */
function findCause<T>(error: unknown, match: (cause: unknown) => cause is T): T | null {
  let cause: unknown = error;
  for (let depth = 0; depth < 32 && cause !== null && typeof cause === 'object'; depth++) {
    if (match(cause)) return cause;
    cause = (cause as { cause?: unknown }).cause;
  }
  return null;
}

/**
 * @dev Whether the wallet declined, at either of the prompts a signature flow puts up: the
 *      typed-data signature and then the transaction. Found by class where viem mapped the
 *      wallet's refusal, and by wording where a wallet phrases it its own way.
 * @param error What the wallet round trip rejected with
 * @return rejected_ Whether the user said no
 */
export const isUserRejection = (error: unknown): boolean =>
  findCause(error, (cause): cause is UserRejectedRequestError => cause instanceof UserRejectedRequestError) !== null ||
  /denied (transaction|message) signature|user rejected/i.test(`${error}`);

/**
 * @dev Whether the wallet did not produce the typed-data signature for a reason that is not the
 *      user's. Every such failure rules both signed flows out - a method the wallet lacks, an
 *      internal error, a hardware keyring that will not sign, an answer with no code at all.
 *      The plain approval always works, so ruling out too much costs one approval, while ruling
 *      out too little leaves a Bridge button that fails the same way on every click and no way
 *      to ask for an approval instead. Only a disconnect is left open: the next click may find
 *      the wallet back. Only the signing step's own failure counts, never a read or a send later
 *      in the flow.
 */
const cannotSignTypedData = (error: unknown): boolean => {
  const signing = findCause(error, (cause): cause is TypedDataSigningError => cause instanceof TypedDataSigningError);
  if (!signing) return false;
  return (
    findCause(
      signing,
      (cause): cause is BaseError =>
        cause instanceof ProviderDisconnectedError || cause instanceof ChainDisconnectedError,
    ) === null
  );
};

/**
 * @dev The name of the custom error a revert decoded to, when the ABI the call was made with
 *      knows it. A revert the ABI cannot name, a string reason or a transport failure is
 *      undefined here, and none of them is a verdict on a signed flow.
 */
const revertedWith = (error: unknown): string | undefined =>
  findCause(error, (cause): cause is ContractFunctionRevertedError => cause instanceof ContractFunctionRevertedError)
    ?.data?.errorName;

/**
 * @dev Which signed flows a failed send rules out for its token, if any.
 *
 *      Only a verdict on the signed flow itself counts: the vault finding no allowance behind
 *      the permit, which is a token whose `permit` is not the one this UI signs for; Permit2
 *      refusing the signature, which is a wallet that does not sign the message the way
 *      Permit2 recovers it; or a wallet that cannot sign typed data at all, which rules out
 *      both. A transport failure, a revert unrelated to the permit (a bad recipient, a paused
 *      bridge, a short fee, a quota) or missing gas money fails a plain send the same way and
 *      a retry may fix it, so those rule out nothing. Nor does a declined prompt.
 *
 * @param error What the send rejected with
 * @param attempted The signed flow the send took
 * @return ruledOut_ The flows to mark unusable for the token this session; empty to keep them
 */
export function permitFlowsRuledOutBy(error: unknown, attempted: PermitMethod): PermitMethod[] {
  if (isUserRejection(error)) return [];
  if (cannotSignTypedData(error)) return ['permit', 'permit2'];

  const errorName = revertedWith(error);
  if (attempted === 'permit' && errorName === VAULT_PERMIT_REJECTED) return ['permit'];
  if (attempted === 'permit2' && errorName !== undefined && PERMIT2_SIGNATURE_REJECTED.has(errorName)) {
    return ['permit2'];
  }
  return [];
}

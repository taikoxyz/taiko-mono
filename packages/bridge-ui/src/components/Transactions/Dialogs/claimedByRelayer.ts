import type { Address } from 'viem';

import { MessageStatus } from '$libs/bridge';

type ClaimedByArgs = {
  /** Who claimed the message, when the relayer told us */
  claimedBy: Maybe<Address | string>;
  /** The message recipient */
  to: Maybe<Address | string>;
  /** The message's destination owner */
  destOwner: Maybe<Address | string>;
  status: Maybe<MessageStatus>;
};

const sameAddress = (a: Maybe<string>, b: Maybe<string>) => Boolean(a) && a?.toLowerCase() === b?.toLowerCase();

/**
 * @dev Whether a claimed message was claimed by a relayer rather than by its own owner.
 *
 *      An unknown claimer is not a relayer. A locally recorded transaction carries no
 *      `claimedBy` at all, so comparing a null claimer against the recipient reported
 *      every self-claimed transaction in the local history as claimed by the relayer.
 *
 * @param args The claimer, the recipient, the destination owner and the message status
 * @return byRelayer_ Whether the claim is attributable to a relayer
 */
export const claimedByRelayer = ({ claimedBy, to, destOwner, status }: ClaimedByArgs) => {
  if (!claimedBy) return false;
  if (status !== MessageStatus.DONE) return false;
  return !sameAddress(claimedBy, to) && !sameAddress(claimedBy, destOwner);
};

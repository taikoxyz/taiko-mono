import type { Message } from '$libs/bridge';

/**
 * Whether anyone other than the destination owner stands to gain by claiming this message first.
 *
 * The bridge only pays the processing fee to a third party when it lets one process the message at
 * all — `gasLimit == 0` reverts with `B_PERMISSION_DENIED` for any sender but the destination owner
 * — and when there is a fee to pay out. Outside those two conditions a race has no prize: claiming
 * someone else's message delivers their funds and costs the sender gas, so nothing is worth hiding
 * from the mempool.
 *
 * @param message The message about to be claimed
 * @returns Whether the claim's processing fee can be taken by someone else
 */
export function isClaimFeeContestable(message: Message): boolean {
  return message.gasLimit !== 0 && message.fee > 0n;
}

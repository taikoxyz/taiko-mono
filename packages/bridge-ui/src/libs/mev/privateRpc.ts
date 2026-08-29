import type { PrivateRpc } from './types';

/**
 * Claiming is a permissionless call: `processMessage(message, proof)` pays the processing fee to
 * whoever lands it first. Broadcasting a claim through the public mempool therefore hands anyone
 * watching the exact calldata needed to take that fee, and the user is left with a reverted
 * transaction they still paid gas for.
 *
 * Flashbots Protect relays transactions directly to block builders instead of gossiping them.
 * `hint=hash` is its maximum privacy setting: MEV-Share searchers only ever see the transaction
 * hash, never the message or the merkle proof. It takes no service fee, and it drops transactions
 * that would revert, so a claim that loses the race costs nothing.
 *
 * @see https://docs.flashbots.net/flashbots-protect/settings-guide
 */
const privateRpcs: Record<number, PrivateRpc> = {
  // Ethereum mainnet
  1: {
    name: 'Flashbots Protect',
    url: 'https://rpc.flashbots.net?hint=hash',
    docsUrl: 'https://docs.flashbots.net/flashbots-protect/overview',
  },
  // Sepolia
  11155111: {
    name: 'Flashbots Protect',
    url: 'https://rpc-sepolia.flashbots.net',
    docsUrl: 'https://docs.flashbots.net/flashbots-protect/overview',
  },
};

/**
 * Returns the private relay covering a chain, or undefined when none does. Only Ethereum has a
 * private relay market today, so claims on Taiko keep using the wallet's own endpoint.
 *
 * @param chainId The chain the claim will be sent to
 * @returns The relay to offer the user, or undefined when the chain has none
 */
export function getPrivateRpc(chainId: number): PrivateRpc | undefined {
  return privateRpcs[chainId];
}

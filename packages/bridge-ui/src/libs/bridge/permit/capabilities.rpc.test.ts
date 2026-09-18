/**
 * The capability probes tell a contract's answer from a transport failure by the shape viem
 * gives the error - and viem gives a gateway's -32603 the same class as a revert. These cases go
 * through a real viem client over a scripted provider, so what is pinned is the error the app
 * sees, not one built by hand.
 */
import { type Address, createPublicClient, custom, encodeAbiParameters, type Hex, toFunctionSelector } from 'viem';
import { vi } from 'vitest';

import { ALICE } from '$mocks';

/** What eth_call answers, by the selector it was called with: a result, or a JSON-RPC error to throw */
type Answer = { result: Hex } | { error: { code: number; message: string; data?: Hex } };
let answers: Record<string, Answer> = {};

const client = createPublicClient({
  // No retries: a transport failure is the answer under test, not something to wait out
  transport: custom(
    {
      request: async ({ method, params }: { method: string; params?: unknown }) => {
        if (method !== 'eth_call') throw { code: -32601, message: 'Method not found' };
        const [{ data }] = params as [{ data: Hex }];
        const answer = answers[data.slice(0, 10)];
        if (!answer) throw { code: 3, message: 'execution reverted', data: '0x' };
        if ('error' in answer) throw answer.error;
        return answer.result;
      },
    },
    { retryCount: 0 },
  ),
});

vi.mock('@wagmi/core', () => ({
  // The app's readContract, minus wagmi's chain routing: the same viem client for every chain
  readContract: (_config: unknown, params: Record<string, unknown>) =>
    client.readContract(Object.fromEntries(Object.entries(params).filter(([key]) => key !== 'chainId')) as never),
  getBytecode: vi.fn(),
}));
vi.mock('$libs/wagmi', () => ({ config: {} }));

import { getPermitDomain, getVaultPermit2, resetPermitCapabilities } from './capabilities';
import { PERMIT2_ADDRESS } from './constants';

const VAULT = '0x1000010000000000000000000000000000000002' as Address;
const TOKEN = '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599' as Address;
const CHAIN = 1;
const PERMIT2_SELECTOR = toFunctionSelector('PERMIT2()');
const DOMAIN_SEPARATOR_SELECTOR = toFunctionSelector('DOMAIN_SEPARATOR()');
const NONCES_SELECTOR = toFunctionSelector('nonces(address)');

const permit2Answer: Answer = { result: encodeAbiParameters([{ type: 'address' }], [PERMIT2_ADDRESS]) };

/** The ways a read fails that mean the contract answered: the flow is settled and remembered */
const contractAnswers: Record<string, Answer> = {
  'a revert with no data, as most nodes report it': { error: { code: 3, message: 'execution reverted', data: '0x' } },
  'a bare revert, as geth reports it': { error: { code: -32000, message: 'execution reverted' } },
  'a revert whose data the ABI cannot name': { error: { code: 3, message: 'execution reverted', data: '0x815e1d64' } },
  'a gateway relaying a revert under its own code': { error: { code: -32603, message: 'execution reverted' } },
  "empty return data, as WETH9's fallback answers": { result: '0x' },
};

/** The ways a read fails that say nothing about the contract: asked again next time */
const transportFailures: Record<string, Answer> = {
  "a gateway's internal error": { error: { code: -32603, message: 'Internal error' } },
  "a gateway's internal JSON-RPC error": { error: { code: -32603, message: 'Internal JSON-RPC error.' } },
  'an upstream timeout relayed as an internal error': { error: { code: -32603, message: 'upstream request timeout' } },
  'a node without the block': { error: { code: -32000, message: 'header not found' } },
  'a rate limit': { error: { code: -32005, message: 'rate limited' } },
};

beforeEach(() => {
  answers = {};
  resetPermitCapabilities();
});

describe('getVaultPermit2 over a real viem client', () => {
  it('reads the canonical Permit2 an upgraded vault names', async () => {
    answers = { [PERMIT2_SELECTOR]: permit2Answer };

    expect(await getVaultPermit2(CHAIN, VAULT)).toBe(PERMIT2_ADDRESS);
  });

  for (const [how, answer] of Object.entries(contractAnswers)) {
    it(`remembers no support after ${how}`, async () => {
      answers = { [PERMIT2_SELECTOR]: answer };
      expect(await getVaultPermit2(CHAIN, VAULT)).toBeNull();

      answers = { [PERMIT2_SELECTOR]: permit2Answer };
      expect(await getVaultPermit2(CHAIN, VAULT)).toBeNull();
    });
  }

  for (const [how, answer] of Object.entries(transportFailures)) {
    it(`asks again after ${how}`, async () => {
      answers = { [PERMIT2_SELECTOR]: answer };
      expect(await getVaultPermit2(CHAIN, VAULT)).toBeNull();

      answers = { [PERMIT2_SELECTOR]: permit2Answer };
      expect(await getVaultPermit2(CHAIN, VAULT)).toBe(PERMIT2_ADDRESS);
    });
  }
});

describe('getPermitDomain over a real viem client', () => {
  const nonce: Answer = { result: encodeAbiParameters([{ type: 'uint256' }], [0n]) };

  for (const [how, answer] of Object.entries(contractAnswers)) {
    it(`settles on no permit after ${how}`, async () => {
      answers = { [DOMAIN_SEPARATOR_SELECTOR]: answer, [NONCES_SELECTOR]: nonce };

      expect(await getPermitDomain(CHAIN, TOKEN, ALICE)).toBeNull();
    });
  }

  for (const [how, answer] of Object.entries(transportFailures)) {
    it(`leaves ${how} to the caller, deciding nothing`, async () => {
      // A null kept from this would send an EIP-2612 token into an unlimited Permit2 approval
      answers = { [DOMAIN_SEPARATOR_SELECTOR]: answer, [NONCES_SELECTOR]: nonce };

      await expect(getPermitDomain(CHAIN, TOKEN, ALICE)).rejects.toThrow();
    });
  }
});

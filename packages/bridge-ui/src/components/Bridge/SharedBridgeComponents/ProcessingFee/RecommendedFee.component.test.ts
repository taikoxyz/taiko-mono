/**
 * The calculating flag is one store shared by every RecommendedFee instance, and the wizard
 * mounts a fresh one on each step. An instance destroyed mid-read used to clear the flag
 * when its read came back, while the next step's instance was still computing - which is
 * what gated that step's Continue.
 */
import { tick } from 'svelte';
import { get } from 'svelte/store';
import { vi } from 'vitest';

const recommendProcessingFee = vi.fn();
vi.mock('$libs/fee', async (importOriginal) => ({
  ...(await importOriginal<typeof import('$libs/fee')>()),
  recommendProcessingFee: (...args: unknown[]) => recommendProcessingFee(...args),
}));

import { calculatingProcessingFee, destNetwork, selectedToken } from '$components/Bridge/state';
import { account } from '$stores/account';
import { connectedSourceChain } from '$stores/network';

import RecommendedFee from './RecommendedFee.svelte';

type Instance = { $destroy: () => void };

/** The read's continuation, including its finally, settles after a macrotask */
const flush = async () => {
  await new Promise((resolve) => setTimeout(resolve, 0));
  await tick();
};

const pendingRead = () => {
  let resolve!: (fee: bigint) => void;
  recommendProcessingFee.mockReturnValueOnce(new Promise<bigint>((r) => (resolve = r)));
  return resolve;
};

let target: HTMLElement;
const mounted: Instance[] = [];

const mount = () => {
  const instance = new RecommendedFee({ target, props: { amount: BigInt(0) } });
  mounted.push(instance);
  return instance;
};

beforeEach(() => {
  recommendProcessingFee.mockReset();
  calculatingProcessingFee.set(false);
  account.set({ address: '0xaaaa', isConnected: true } as never);
  connectedSourceChain.set({ id: 1 } as never);
  destNetwork.set({ id: 2 } as never);
  selectedToken.set({ type: 'ETH', symbol: 'ETH', decimals: 18, addresses: {} } as never);
  target = document.createElement('div');
  document.body.appendChild(target);
});

afterEach(() => {
  mounted.splice(0).forEach((instance) => instance.$destroy());
  target.remove();
});

describe('the calculating flag across instances', () => {
  it('stays raised for the next instance when a destroyed one finishes its read', async () => {
    const finishA = pendingRead();
    const a = mount();
    await tick();
    expect(get(calculatingProcessingFee)).toBe(true);

    // A step change: A goes, B starts its own read
    a.$destroy();
    const finishB = pendingRead();
    mount();
    await tick();
    expect(get(calculatingProcessingFee)).toBe(true);

    finishA(BigInt(1));
    await flush();

    // B is still computing; this used to read false and enable Continue on a 0 ETH fee
    expect(get(calculatingProcessingFee)).toBe(true);

    finishB(BigInt(2));
    await flush();
    expect(get(calculatingProcessingFee)).toBe(false);
  });

  it('lowers the flag when the only computing instance is destroyed', async () => {
    pendingRead();
    const a = mount();
    await tick();
    expect(get(calculatingProcessingFee)).toBe(true);

    // Leaving for a step with no fee to compute: nothing is calculating any more
    a.$destroy();

    expect(get(calculatingProcessingFee)).toBe(false);
  });

  it('lowers the flag once a lone read completes', async () => {
    const finish = pendingRead();
    mount();
    await tick();

    finish(BigInt(1));
    await flush();

    expect(get(calculatingProcessingFee)).toBe(false);
  });
});

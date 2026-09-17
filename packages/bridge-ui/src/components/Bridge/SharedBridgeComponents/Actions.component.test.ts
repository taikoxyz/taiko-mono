/**
 * The Approve button is for what the plan approves, and says so: the one-time Permit2
 * approval carries its explanation, and a token that will be signed for instead reports
 * that no approval is needed rather than "Approved".
 */
import { tick } from 'svelte';
import { vi } from 'vitest';

window.matchMedia = vi.fn().mockReturnValue({
  matches: true,
  addEventListener: vi.fn(),
  removeEventListener: vi.fn(),
}) as never;

vi.mock('svelte-i18n', async () => {
  const { readable } = await import('svelte/store');
  const t = (key: string, options?: { values?: Record<string, unknown> }) =>
    options?.values ? `${key} ${JSON.stringify(options.values)}` : key;
  return { t: readable(t), locale: readable('en'), init: vi.fn(), addMessages: vi.fn() };
});
vi.mock('$chainConfig', () => ({
  chainConfig: {
    1: { name: 'Ethereum', type: 'L1', rpcUrls: { default: { http: ['https://l1.rpc'] } } },
    2: { name: 'Taiko', type: 'L2', rpcUrls: { default: { http: ['https://l2.rpc'] } } },
  },
}));
// The status read the component takes on mount, scripted per test
const getTokenApprovalStatus = vi.fn();
vi.mock('$libs/token/getTokenApprovalStatus', async (importOriginal) => ({
  ...(await importOriginal<typeof import('$libs/token/getTokenApprovalStatus')>()),
  getTokenApprovalStatus: (...args: unknown[]) => getTokenApprovalStatus(...args),
}));

import {
  allApproved,
  destNetwork,
  enteredAmount,
  erc20SendPlan,
  selectedToken,
  tokenBalance,
} from '$components/Bridge/state';
import { TokenType } from '$libs/token';
import { ALICE } from '$mocks';
import { account } from '$stores/account';
import { connectedSourceChain } from '$stores/network';

import Actions from './Actions.svelte';

const TOKEN = '0x00000000000000000000000000000000000000c0';
const VAULT = '0x2000010000000000000000000000000000000002';
const PERMIT2 = '0x000000000022D473030F116dDEE9F6B43aC78BA3';
const MAX = 2n ** 256n - 1n;
const usdt = { type: TokenType.ERC20, symbol: 'USDT', name: 'Tether', decimals: 6, addresses: { 2: TOKEN } };

let target: HTMLElement;
let component: { $destroy: () => void } | null = null;

const flush = async () => {
  await new Promise((resolve) => setTimeout(resolve, 0));
  await tick();
};

const mount = async () => {
  target = document.createElement('div');
  document.body.appendChild(target);
  component = new Actions({
    target,
    props: { approve: vi.fn(), bridge: vi.fn(), resetApproval: vi.fn() },
  });
  await flush();
};

const approveButton = () => target.querySelectorAll('button')[0];

beforeEach(() => {
  vi.clearAllMocks();
  account.set({ address: ALICE, isConnected: true } as never);
  connectedSourceChain.set({ id: 2, name: 'Taiko' } as never);
  destNetwork.set({ id: 1, name: 'Ethereum' } as never);
  selectedToken.set(usdt as never);
  tokenBalance.set({ value: BigInt(100) } as never);
  enteredAmount.set(BigInt(5));
});

afterEach(() => {
  component?.$destroy();
  component = null;
  target.remove();
});

describe('the Approve button', () => {
  it('explains the one-time Permit2 approval the plan asks for', async () => {
    getTokenApprovalStatus.mockImplementation(async () => {
      erc20SendPlan.set({ method: 'approve', spender: PERMIT2, amount: MAX, currentAllowance: 0n, target: 'permit2' });
      allApproved.set(false);
    });
    await mount();

    expect(target.textContent).toContain('bridge.permit2_approval.info {"token":"USDT"}');
    expect(approveButton().textContent).toContain('bridge.button.approve');
  });

  it('says nothing special about a plain vault approval', async () => {
    getTokenApprovalStatus.mockImplementation(async () => {
      erc20SendPlan.set({
        method: 'approve',
        spender: VAULT,
        amount: BigInt(5),
        currentAllowance: 0n,
        target: 'vault',
      });
      allApproved.set(false);
    });
    await mount();

    expect(target.textContent).not.toContain('bridge.permit2_approval.info');
    expect(approveButton().textContent).toContain('bridge.button.approve');
  });

  it('reports that no approval is needed when Bridge will ask for a signature instead', async () => {
    getTokenApprovalStatus.mockImplementation(async () => {
      erc20SendPlan.set({ method: 'permit2', permit2: PERMIT2 });
      allApproved.set(true);
    });
    await mount();

    expect(approveButton().textContent).toContain('bridge.button.no_approval_needed');
    expect(approveButton().textContent).not.toContain('bridge.button.approved');
    expect(target.textContent).not.toContain('bridge.permit2_approval.info');
  });

  it('still reads "Approved" for an allowance that was granted', async () => {
    getTokenApprovalStatus.mockImplementation(async () => {
      erc20SendPlan.set({ method: 'sendToken' });
      allApproved.set(true);
    });
    await mount();

    expect(approveButton().textContent).toContain('bridge.button.approved');
  });
});

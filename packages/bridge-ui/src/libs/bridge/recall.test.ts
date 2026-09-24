import { type Config, createConfig } from '@wagmi/core';
import { encodeAbiParameters, http, toFunctionSelector } from 'viem';
import { mainnet } from 'viem/chains';

import { env } from '$env/dynamic/public';

// Exercise the installed wagmi/viem error wrapping; mock only the HTTP response.
vi.unmock('@wagmi/core');
const holder = vi.hoisted(() => ({ config: undefined as Config | undefined }));
vi.mock('$libs/wagmi', () => ({
  get config() {
    return holder.config;
  },
}));

import { getRecallState } from './recall';

type RpcReply = { result?: string | null; error?: { code: number; message: string; data?: unknown } };
const unpaused: RpcReply = { result: encodeAbiParameters([{ type: 'bool' }], [false]) };

function mockRpc(recallReply: RpcReply, pausedReply: RpcReply = unpaused) {
  const calls: string[] = [];
  vi.stubGlobal(
    'fetch',
    vi.fn(async (_url: string, init: RequestInit) => {
      const body = JSON.parse(init.body as string);
      const selector = body.params[0].data;
      calls.push(selector);
      if (body.method !== 'eth_call') throw new Error(`Unexpected RPC method: ${body.method}`);
      const reply = selector === toFunctionSelector('recallEnabled()') ? recallReply : pausedReply;
      return new Response(JSON.stringify({ jsonrpc: '2.0', id: body.id, ...reply }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    }),
  );
  return calls;
}

beforeEach(() => {
  delete env.PUBLIC_BRIDGE_RECALL_ENABLED;
  holder.config = createConfig({
    chains: [mainnet],
    transports: { [mainnet.id]: http('https://rpc.test.invalid', { retryCount: 0 }) },
    batch: { multicall: false },
    storage: null,
  });
});
afterEach(() => {
  vi.unstubAllGlobals();
});

it.each<RpcReply>([
  { result: '0x' },
  { error: { code: 3, message: 'execution reverted', data: '0x' } },
  { error: { code: 3, message: 'Execution reverted', data: '0x' } },
  { error: { code: -32603, message: 'Execution reverted', data: '0x' } },
  { error: { code: -32000, message: 'execution reverted' } },
  { error: { code: -32000, message: 'execution reverted', data: '0x' } },
  { error: { code: -32000, message: 'Execution reverted' } },
])('recognizes a responsive legacy bridge after the missing getter returns %j', async (reply) => {
  const calls = mockRpc(reply);
  await expect(getRecallState(1, 2)).resolves.toBe('enabled');
  expect(calls).toEqual([toFunctionSelector('recallEnabled()'), toFunctionSelector('paused()')]);
});

it.each<RpcReply>([
  {},
  { result: null },
  { error: { code: -32000, message: 'request limit exceeded' } },
  { error: { code: -32000, message: 'execution reverted: unauthorized' } },
  { error: { code: -32000, message: 'execution reverted', data: '0x12345678' } },
  { error: { code: -32000, message: 'execution reverted', data: { data: '0x12345678' } } },
  { error: { code: 3, message: 'execution reverted', data: '0x12345678' } },
  { error: { code: 3, message: 'execution reverted: unauthorized', data: '0x' } },
  { error: { code: -32601, message: 'Method not found' } },
  { result: '0x01' },
])('does not treat an unrelated failure or malformed return as a missing getter: %j', async (reply) => {
  const calls = mockRpc(reply);
  await expect(getRecallState(1, 2)).resolves.toBe('unknown');
  expect(calls).toEqual([toFunctionSelector('recallEnabled()')]);
});

it.each([3, -32603])('rejects nested custom revert data before viem discards it (RPC code %s)', async (code) => {
  const calls = mockRpc({
    error: {
      code,
      message: 'Execution reverted',
      data: { originalError: { code: 3, message: 'execution reverted: unauthorized', data: '0x12345678' } },
    },
  });
  await expect(getRecallState(1, 2)).resolves.toBe('unknown');
  expect(calls).toEqual([toFunctionSelector('recallEnabled()')]);
});

it.each<RpcReply>([{ result: '0x' }, { error: { code: -32000, message: 'execution reverted' } }])(
  'requires a responsive paused getter before enabling legacy recalls: %j',
  async (pausedReply) => {
    mockRpc({ error: { code: -32000, message: 'execution reverted' } }, pausedReply);
    await expect(getRecallState(1, 2)).resolves.toBe('unknown');
  },
);

it.each([true, false])(
  'honors an upgraded bridge reporting recallEnabled=%s without a legacy probe',
  async (enabled) => {
    const calls = mockRpc({ result: encodeAbiParameters([{ type: 'bool' }], [enabled]) });
    await expect(getRecallState(1, 2)).resolves.toBe(enabled ? 'enabled' : 'disabled');
    expect(calls).toEqual([toFunctionSelector('recallEnabled()')]);
  },
);

it('leaves recall availability unknown after a transport failure', async () => {
  vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('Failed to fetch')));
  await expect(getRecallState(1, 2)).resolves.toBe('unknown');
});

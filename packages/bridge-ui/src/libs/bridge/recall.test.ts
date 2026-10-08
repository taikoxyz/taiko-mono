import { type Config, createConfig } from '@wagmi/core';
import { encodeAbiParameters, http, toFunctionSelector } from 'viem';
import { mainnet } from 'viem/chains';

import { routingContractsMap } from '$bridgeConfig';

// Exercise the installed wagmi/viem error wrapping; mock only the HTTP response.
vi.unmock('@wagmi/core');
const { publicEnv } = vi.hoisted(() => ({ publicEnv: {} as Record<string, string | undefined> }));
vi.mock('$env/dynamic/public', () => ({ env: publicEnv }));
const holder = vi.hoisted(() => ({ config: undefined as Config | undefined }));
vi.mock('$libs/wagmi', () => ({
  get config() {
    return holder.config;
  },
}));

import { getFinalRetryState, getRecallState, type RecallState } from './recall';

type RpcReply = { result?: string | null; error?: { code: number; message: string; data?: unknown } };
const unpaused: RpcReply = { result: encodeAbiParameters([{ type: 'bool' }], [false]) };
const recallEnabled: RpcReply = { result: encodeAbiParameters([{ type: 'bool' }], [true]) };

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((resolvePromise) => {
    resolve = resolvePromise;
  });
  return { promise, resolve };
}

function mockRpc(
  recallReply: RpcReply | ((url: string, address: string) => RpcReply | Promise<RpcReply>),
  pausedReply: RpcReply = unpaused,
) {
  const calls: string[] = [];
  vi.stubGlobal(
    'fetch',
    vi.fn(async (url: string, init: RequestInit) => {
      const body = JSON.parse(init.body as string);
      const selector = body.params[0].data;
      calls.push(selector);
      if (body.method !== 'eth_call') throw new Error(`Unexpected RPC method: ${body.method}`);
      const reply =
        selector === toFunctionSelector('recallEnabled()')
          ? typeof recallReply === 'function'
            ? await recallReply(url, body.params[0].to)
            : recallReply
          : pausedReply;
      return new Response(JSON.stringify({ jsonrpc: '2.0', id: body.id, ...reply }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    }),
  );
  return calls;
}

beforeEach(() => {
  delete publicEnv.PUBLIC_BRIDGE_RECALL_ENABLED;
  holder.config = createConfig({
    chains: [mainnet, { ...mainnet, id: 2 }],
    transports: {
      [mainnet.id]: http('https://rpc-1.test.invalid', { retryCount: 0 }),
      2: http('https://rpc-2.test.invalid', { retryCount: 0 }),
    },
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
  { error: { code: 3, message: 'execution reverted', data: null } },
  { error: { code: 3, message: 'EXECUTION REVERTED' } },
  { error: { code: -32000, message: 'execution reverted' } },
  { error: { code: -32000, message: 'execution reverted', data: '0x' } },
  { error: { code: -32000, message: 'Execution reverted' } },
  { error: { code: -32000, message: 'execution reverted', data: null } },
])('recognizes a responsive legacy bridge after the missing getter returns %j', async (reply) => {
  const calls = mockRpc(reply);
  await expect(getRecallState(1, 2)).resolves.toBe('enabled');
  expect(calls).toEqual([toFunctionSelector('recallEnabled()'), toFunctionSelector('paused()')]);
});

it.each<RpcReply>([
  {},
  { result: null },
  { error: { code: -32603, message: 'Execution reverted', data: '0x' } },
  { error: { code: -32603, message: 'execution reverted', data: null } },
  { error: { code: -32603, message: 'execution reverted' } },
  { error: { code: -32000, message: 'request limit exceeded' } },
  { error: { code: -32000, message: 'execution reverted: unauthorized' } },
  { error: { code: -32000, message: 'execution reverted', data: '0x12345678' } },
  { error: { code: -32000, message: 'execution reverted', data: { data: '0x12345678' } } },
  { error: { code: 3, message: 'execution reverted', data: '0x12345678' } },
  { error: { code: 3, message: 'execution reverted: unauthorized', data: '0x' } },
  { error: { code: 3, message: 'execution reverted without a reason string', data: null } },
  { error: { code: -32000, message: 'execution reverted (no data)', data: null } },
  { error: { code: 3, message: ' execution reverted ', data: null } },
  { error: { code: -32601, message: 'Method not found' } },
  { result: '0x01' },
])('does not treat an unrelated failure or malformed return as a missing getter: %j', async (reply) => {
  const calls = mockRpc(reply);
  await expect(getRecallState(1, 2)).resolves.toBe('unknown');
  expect(calls).toEqual([toFunctionSelector('recallEnabled()')]);
});

it.each([3, -32000, -32603])(
  'rejects nested custom revert data before viem discards it (RPC code %s)',
  async (code) => {
    const calls = mockRpc({
      error: {
        code,
        message: 'Execution reverted',
        data: { originalError: { code: 3, message: 'execution reverted: unauthorized', data: '0x12345678' } },
      },
    });
    await expect(getRecallState(1, 2)).resolves.toBe('unknown');
    expect(calls).toEqual([toFunctionSelector('recallEnabled()')]);
  },
);

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

it.each([undefined, '', ' ', 'true', 'TRUE', ' true '])(
  'detects recall availability for an automatic flag (%j)',
  async (flag) => {
    publicEnv.PUBLIC_BRIDGE_RECALL_ENABLED = flag;
    const calls = mockRpc({ result: encodeAbiParameters([{ type: 'bool' }], [false]) });
    await expect(getRecallState(1, 2)).resolves.toBe('disabled');
    expect(calls).toEqual([toFunctionSelector('recallEnabled()')]);
  },
);

it.each(['false', 'FALSE', ' false ', '0', 'no', 'unexpected'])(
  'disables recalls without an RPC read for any other nonempty flag (%j)',
  async (flag) => {
    publicEnv.PUBLIC_BRIDGE_RECALL_ENABLED = flag;
    const calls = mockRpc({ result: encodeAbiParameters([{ type: 'bool' }], [true]) });
    await expect(getRecallState(1, 2)).resolves.toBe('disabled');
    expect(calls).toEqual([]);
  },
);

it.each<RpcReply>([recallEnabled, { result: '0x' }])(
  'shares concurrent capability reads for the same bridge: %j',
  async (reply) => {
    const calls = mockRpc(reply);
    await expect(Promise.all([getRecallState(1, 2), getRecallState(1, 2), getRecallState(1, 2)])).resolves.toEqual([
      'enabled',
      'enabled',
      'enabled',
    ]);
    expect(calls).toEqual(
      reply.result === '0x'
        ? [toFunctionSelector('recallEnabled()'), toFunctionSelector('paused()')]
        : [toFunctionSelector('recallEnabled()')],
    );
  },
);

it('re-reads the bridge after a shared read settles', async () => {
  let reply = recallEnabled;
  const calls = mockRpc(() => reply);
  await expect(getRecallState(1, 2)).resolves.toBe('enabled');
  reply = unpaused;
  await expect(getRecallState(1, 2)).resolves.toBe('disabled');
  expect(calls).toEqual([toFunctionSelector('recallEnabled()'), toFunctionSelector('recallEnabled()')]);
});

it('does not retain an unsuccessful shared read', async () => {
  let reply: RpcReply = {};
  const calls = mockRpc(() => reply);
  await expect(getRecallState(1, 2)).resolves.toBe('unknown');
  reply = recallEnabled;
  await expect(getRecallState(1, 2)).resolves.toBe('enabled');
  expect(calls).toEqual([toFunctionSelector('recallEnabled()'), toFunctionSelector('recallEnabled()')]);
});

it('keeps simultaneous capability reads for different source chains separate', async () => {
  const calls = mockRpc((url) => (url.includes('rpc-1') ? recallEnabled : unpaused));
  await expect(Promise.all([getRecallState(1, 2), getRecallState(2, 1)])).resolves.toEqual(['enabled', 'disabled']);
  expect(calls).toEqual([toFunctionSelector('recallEnabled()'), toFunctionSelector('recallEnabled()')]);
});

it('does not share reads for different bridge addresses on the same chain', async () => {
  const route = routingContractsMap[1][2];
  const previousAddress = route.bridgeAddress;
  const calls = mockRpc((_url, address) => (address === previousAddress ? recallEnabled : unpaused));
  try {
    const previous = getRecallState(1, 2);
    route.bridgeAddress = '0x0000000000000000000000000000000000000001';
    const current = getRecallState(1, 2);
    await expect(Promise.all([previous, current])).resolves.toEqual(['enabled', 'disabled']);
    expect(calls).toHaveLength(2);
  } finally {
    route.bridgeAddress = previousAddress;
  }
});

it('a fresh read bypasses an older unresolved UI read', async () => {
  const older = deferred<RpcReply>();
  let reads = 0;
  const calls = mockRpc(() => (++reads === 1 ? older.promise : unpaused));
  const background = getRecallState(1, 2);
  await vi.waitFor(() => expect(calls).toHaveLength(1));
  const fresh = getRecallState(1, 2, { fresh: true });
  let freshState: RecallState | undefined;
  void fresh.then((state) => {
    freshState = state;
  });
  try {
    await vi.waitFor(() => expect(freshState).toBe('disabled'));
    expect(calls).toHaveLength(2);
  } finally {
    older.resolve(recallEnabled);
    await Promise.all([background, fresh]);
  }
});

it.each([1, 2])('a fresh final-retry check bypasses an unresolved UI read on chain %s', async (chainId) => {
  const older = deferred<RpcReply>();
  let reads = 0;
  const calls = mockRpc((url) => {
    if (!url.includes(`rpc-${chainId}`)) return recallEnabled;
    return ++reads === 1 ? older.promise : unpaused;
  });
  const background = getRecallState(chainId, chainId === 1 ? 2 : 1);
  await vi.waitFor(() => expect(calls).toHaveLength(1));
  const fresh = getFinalRetryState({ srcChainId: 1n, destChainId: 2n }, { fresh: true });
  let freshState: RecallState | undefined;
  void fresh.then((state) => {
    freshState = state;
  });
  try {
    await vi.waitFor(() => expect(freshState).toBe('disabled'));
    expect(calls).toHaveLength(3);
  } finally {
    older.resolve(recallEnabled);
    await Promise.all([background, fresh]);
  }
});

it('checks the operator flag before sharing an older enabled read', async () => {
  const older = deferred<RpcReply>();
  const calls = mockRpc(() => older.promise);
  const background = getRecallState(1, 2);
  await vi.waitFor(() => expect(calls).toHaveLength(1));
  publicEnv.PUBLIC_BRIDGE_RECALL_ENABLED = 'false';
  try {
    await expect(getRecallState(1, 2)).resolves.toBe('disabled');
    expect(calls).toHaveLength(1);
  } finally {
    older.resolve(recallEnabled);
    await background;
  }
});

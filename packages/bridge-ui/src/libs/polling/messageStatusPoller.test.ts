/**
 * The emitter and interval maps are keyed by `msgHash`. Reviews have repeatedly read that
 * as an `undefined` bucket shared by every un-enhanced local transaction; it is not, because
 * a missing `msgHash` is refused before either map is touched. This pins that ordering so
 * the guard cannot be removed without the maps' key becoming a real question again.
 */
import { BridgeTxPollingError } from '$libs/error';

const messageStatusRead = vi.hoisted(() => vi.fn());
// The manual mock at __mocks__/@wagmi/core.ts does not stub getTransactionReceipt, and an
// automocked export is undefined rather than a spy, so it is supplied here
const getTransactionReceiptMock = vi.hoisted(() => vi.fn());

vi.mock('@wagmi/core', async () => ({
  ...(await vi.importActual<Record<string, unknown>>('../../../__mocks__/@wagmi/core')),
  getTransactionReceipt: getTransactionReceiptMock,
}));
vi.mock('$bridgeConfig');
vi.mock('viem', async (importOriginal) => ({
  ...(await importOriginal<typeof import('viem')>()),
  createPublicClient: () => ({}),
  getContract: () => ({ read: { messageStatus: messageStatusRead } }),
}));

import { type BridgeTransaction, MessageStatus } from '$libs/bridge';

import { PollingEvent, startPolling } from './messageStatusPoller';

const tx = (overrides: Partial<BridgeTransaction> = {}) =>
  ({
    srcTxHash: '0xtx',
    srcChainId: BigInt(1),
    destChainId: BigInt(2),
    msgHash: '0xmsg',
    ...overrides,
  }) as unknown as BridgeTransaction;

describe('startPolling', () => {
  it('refuses a transaction with no message hash', () => {
    expect(() => startPolling(tx({ msgHash: undefined }))).toThrow(BridgeTxPollingError);
  });

  it('refuses before it can key anything by an absent hash', () => {
    // Two un-enhanced transactions would share one emitter and one interval if either
    // reached the maps. Neither does: both are refused on the way in
    expect(() => startPolling(tx({ srcTxHash: '0xa', msgHash: undefined }))).toThrow(BridgeTxPollingError);
    expect(() => startPolling(tx({ srcTxHash: '0xb', msgHash: undefined }))).toThrow(BridgeTxPollingError);
  });

  it('gives two messages from one transaction their own pollers', () => {
    const first = startPolling(tx({ srcTxHash: '0xtx', msgHash: '0xmsgA' }), false);
    const second = startPolling(tx({ srcTxHash: '0xtx', msgHash: '0xmsgB' }), false);

    // Keyed by transaction, the second call returned the first's emitter and the second
    // message was never polled
    expect(first?.emitter).not.toBe(second?.emitter);

    first?.destroy({});
    second?.destroy({});
  });

  it('shares one poller between two subscribers of the same message', () => {
    const first = startPolling(tx({ msgHash: '0xshared' }), false);
    const second = startPolling(tx({ msgHash: '0xshared' }), false);

    expect(first?.emitter).toBe(second?.emitter);

    first?.destroy({});
  });

  it('stops polling a completed message even when the source receipt cannot be read', async () => {
    // The DONE check used to sit after the receipt read, so a source RPC that could not
    // serve the receipt threw past it into the catch that deliberately keeps the interval
    // alive: every tick re-read DONE, re-emitted it and never stopped, for a message that
    // was already finalised.
    vi.useFakeTimers();
    messageStatusRead.mockResolvedValue(MessageStatus.DONE);
    getTransactionReceiptMock.mockRejectedValue(new Error('source rpc down'));

    const polling = startPolling(tx({ msgHash: '0xdone', blockNumber: undefined }));
    const onStatus = vi.fn();
    polling?.emitter.on(PollingEvent.STATUS, onStatus);

    // The first run is deferred to the next tick so listeners can attach first
    await vi.advanceTimersByTimeAsync(1);
    expect(onStatus).toHaveBeenCalledWith(MessageStatus.DONE);

    // Several intervals later there must have been no second read of a finalised message
    await vi.advanceTimersByTimeAsync(20_000 * 3);
    expect(onStatus).toHaveBeenCalledTimes(1);

    polling?.destroy({});
    vi.useRealTimers();
  });
});

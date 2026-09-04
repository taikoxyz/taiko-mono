/**
 * startWatching awaits the wallet reconnection before it subscribes. A layout torn down
 * during that wait called stopWatching, found nothing to unwatch, and then the await
 * returned and installed a subscription nothing would ever remove.
 */
import { vi } from 'vitest';

const watchAccount = vi.fn();
const unwatch = vi.fn();
// vi.mock factories are hoisted above every other statement, so the deferred promise they
// close over has to be created through vi.hoisted rather than a plain top-level `let`
const reconnection = vi.hoisted(() => {
  let resolve!: () => void;
  const promise = new Promise<void>((r) => (resolve = r));
  return { promise, resolve };
});

vi.mock('@wagmi/core', () => ({
  getAccount: vi.fn().mockReturnValue({ isConnected: false }),
  watchAccount: (...args: unknown[]) => watchAccount(...args),
  createConfig: vi.fn(),
  http: vi.fn(),
  reconnect: vi.fn(),
}));
vi.mock('$libs/util/checkForPausedContracts', () => ({ checkForPausedContracts: vi.fn().mockResolvedValue(false) }));
vi.mock('$libs/util/isSmartContract', () => ({ isSmartContract: vi.fn().mockResolvedValue(false) }));
vi.mock('$libs/util/balance', () => ({ refreshUserBalance: vi.fn() }));
vi.mock('./client', () => ({
  config: {},
  reconnectionPromise: reconnection.promise,
}));

import { startWatching, stopWatching } from './watcher';

const flush = async () => await new Promise((resolve) => setTimeout(resolve, 0));

beforeEach(() => {
  watchAccount.mockReset().mockReturnValue(unwatch);
  unwatch.mockReset();
});

describe('startWatching / stopWatching', () => {
  it('does not subscribe for a layout that was torn down while the wallet was reconnecting', async () => {
    const starting = startWatching();
    stopWatching(); // the layout unmounts before reconnection settles

    reconnection.resolve();
    await starting;
    await flush();

    expect(watchAccount).not.toHaveBeenCalled();
  });

  it('subscribes once reconnection settles for a layout that is still there, and unsubscribes on stop', async () => {
    const starting = startWatching();
    await starting;
    await flush();

    expect(watchAccount).toHaveBeenCalledTimes(1);

    stopWatching();
    expect(unwatch).toHaveBeenCalledTimes(1);
  });
});

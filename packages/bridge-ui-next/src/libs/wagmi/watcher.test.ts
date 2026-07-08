import { getAccount, watchAccount } from "@wagmi/core";
import { beforeEach, describe, expect, it, vi } from "vitest";

const { reconnection } = vi.hoisted(() => {
  let resolve!: () => void;
  const promise = new Promise<void>((r) => {
    resolve = r;
  });
  return { reconnection: { promise, resolve } };
});

vi.mock("./client", () => ({
  config: {},
  reconnectionPromise: reconnection.promise,
}));
vi.mock("@/libs/util/checkForPausedContracts", () => ({
  checkForPausedContracts: vi.fn().mockResolvedValue(undefined),
}));
vi.mock("@/libs/util/balance", () => ({
  refreshUserBalance: vi.fn(),
}));
vi.mock("@/libs/util/isSmartContract", () => ({
  isSmartContract: vi.fn().mockResolvedValue(false),
}));

import { startWatching, stopWatching } from "./watcher";

describe("wagmi account watcher lifecycle", () => {
  const unwatch = vi.fn();

  beforeEach(() => {
    unwatch.mockClear();
    vi.mocked(watchAccount).mockClear();
    vi.mocked(watchAccount).mockReturnValue(unwatch);
    vi.mocked(getAccount).mockReturnValue({
      isConnected: false,
    } as unknown as ReturnType<typeof getAccount>);
  });

  it("survives StrictMode mount→cleanup→remount: no throw, single subscription", async () => {
    // Effect mounts: startWatching suspends awaiting wagmi reconnection.
    const first = startWatching();

    // StrictMode immediately runs the cleanup while the first call is still
    // pre-subscription. This must not throw (unWatchAccount is not assigned
    // yet) …
    expect(() => stopWatching()).not.toThrow();

    // … and the remounted effect starts watching again.
    const second = startWatching();

    reconnection.resolve();
    await first;
    await second;

    // Only the surviving start may register a watcher — the torn-down first
    // call must not double-subscribe (duplicate account handlers = duplicate
    // RPCs and an unsubscribable leak).
    expect(watchAccount).toHaveBeenCalledTimes(1);
  });

  it("stopWatching unsubscribes an active watcher", async () => {
    // The previous test left the watcher active (module singleton state).
    stopWatching();
    expect(unwatch).toHaveBeenCalledTimes(1);

    // And the cycle can start cleanly again.
    await startWatching();
    expect(watchAccount).toHaveBeenCalledTimes(1);
  });
});

import { describe, expect, it, vi } from "vitest";

import { createValueStore } from "./createValueStore";

describe("createValueStore", () => {
  it("replaces arrays wholesale instead of merging them", () => {
    const store = createValueStore<number[]>(() => []);
    store.setState([1, 2, 3]);
    store.setState([4]);

    expect(store.getState()).toEqual([4]);
    expect(Array.isArray(store.getState())).toBe(true);
  });

  it("replaces objects wholesale, dropping keys absent from the new value", () => {
    const store = createValueStore<Record<string, number>>(() => ({ a: 1 }));
    store.setState({ b: 2 });

    expect(store.getState()).toEqual({ b: 2 });
    expect("a" in store.getState()).toBe(false);
  });

  it("supports updater functions, replacing with their return value", () => {
    const store = createValueStore<{ count: number; extra?: boolean }>(() => ({
      count: 0,
      extra: true,
    }));
    store.setState((prev) => ({ count: prev.count + 1 }));

    expect(store.getState()).toEqual({ count: 1 });
  });

  it("still notifies subscribers", () => {
    const store = createValueStore<number>(() => 0);
    const listener = vi.fn();
    store.subscribe(listener);
    store.setState(5);

    expect(listener).toHaveBeenCalledTimes(1);
    expect(store.getState()).toBe(5);
  });
});

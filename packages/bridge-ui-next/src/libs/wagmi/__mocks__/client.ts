// Manual vitest mock for `$libs/wagmi/client` (picked up by
// `vi.mock("$libs/wagmi/client")`). Ported from the original bridge-ui's
// `__mocks__/@wagmi/core.ts` createConfig stub: tests assert wagmi actions are
// called with this concrete config object.
export const config = {
  chains: [],
};

export const reconnectionPromise = Promise.resolve();

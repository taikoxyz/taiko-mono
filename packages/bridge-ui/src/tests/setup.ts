import dotenv from 'dotenv';

dotenv.config({ path: './.env.test' });

vi.mock('@wagmi/core');

// jsdom does not implement matchMedia, which Svelte's motion runtime reads at import time.
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: vi.fn((media: string) => ({
    matches: false,
    media,
    onchange: null,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(() => true),
  })),
});

// Source: https://github.com/vitest-dev/vitest/issues/4043#issuecomment-1905172846
// This snippet is needed in order to support Uint8Array with vitest and jsdom.
if (process.env.VITEST === 'true') {
  class ESBuildAndJSDOMCompatibleTextEncoder extends TextEncoder {
    constructor() {
      super();
    }

    encode(input: string) {
      if (typeof input !== 'string') {
        throw new TypeError('`input` must be a string');
      }

      const decodedURI = decodeURIComponent(encodeURIComponent(input));
      const arr = new Uint8Array(decodedURI.length);
      const chars = decodedURI.split('');
      for (let i = 0; i < chars.length; i++) {
        arr[i] = decodedURI[i].charCodeAt(0);
      }
      return arr;
    }
  }

  Object.defineProperty(global, 'TextEncoder', {
    value: ESBuildAndJSDOMCompatibleTextEncoder,
    writable: true,
  });
}

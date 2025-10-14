import { BridgeTxService } from './BridgeTxService';
import { CustomTokenService } from './CustomTokenService';

// Provide a no-op storage fallback for SSR environments where localStorage is unavailable
const safeStorage: Storage = typeof globalThis !== 'undefined' && 'localStorage' in globalThis
  ? (globalThis as any).localStorage
  : ({
      length: 0,
      clear() {},
      getItem(_key: string) { return null; },
      key(_index: number) { return null; },
      removeItem(_key: string) {},
      setItem(_key: string, _value: string) {}
    } as Storage);

export const bridgeTxService = new BridgeTxService(safeStorage);

export const customTokenService = new CustomTokenService(safeStorage);

import { describe, expect, it, vi } from 'vitest';

import { TTKOIcon, ZKCIcon } from '$components/Icon';

import { symbolToIconMap } from './symbolToIconMap';

vi.mock('$components/Icon', () => ({
  BllIcon: Symbol('BLL'),
  EthIcon: Symbol('ETH'),
  HorseIcon: Symbol('HORSE'),
  TTKOIcon: Symbol('TTKO'),
  ZKCIcon: Symbol('ZKC'),
}));

describe('symbolToIconMap', () => {
  it('returns the ZKC icon for the exact ZKC symbol', () => {
    expect(symbolToIconMap.ZKC).toBe(ZKCIcon);
  });

  it('keeps resolving TAIKO-prefixed symbols to the TTKO icon', () => {
    expect(symbolToIconMap.TAIKO).toBe(TTKOIcon);
    expect(symbolToIconMap.TAIKO_HOODI).toBe(TTKOIcon);
  });

  it('returns null for unknown symbols', () => {
    expect(symbolToIconMap.UNKNOWN).toBeNull();
  });
});

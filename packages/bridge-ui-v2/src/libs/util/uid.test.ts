import { uid } from './uid';

describe('uid', () => {
  it('should always return a unique id', () => {
    const generatedIds = new Set<string>();

    // Is this unique enough? 😅
    for (let i = 0; i < 1000; i++) {
      generatedIds.add(uid());
    }

    expect(generatedIds.size).toBe(1000);
  });
});

import { Deferred } from './Deferred';

describe('Deferred', () => {
  it('should resolve', async () => {
    const deferred = new Deferred();
    deferred.resolve('test');
    expect(await deferred.promise).toBe('test');
  });

  it('should reject', async () => {
    const deferred = new Deferred();
    deferred.reject('test');
    await expect(deferred.promise).rejects.toBe('test');
  });
});

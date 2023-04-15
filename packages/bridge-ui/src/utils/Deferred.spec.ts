import { Deferred } from './Deferred';

describe('Deferred', () => {
  it('should resolve', async () => {
    const deferred = new Deferred();
    deferred.resolve('test');

    try {
      await expect(deferred.promise).resolves.toBe('test');
    } catch (e) {
      throw Error('This should never happen');
    }
  });

  it('should reject', async () => {
    const deferred = new Deferred();
    deferred.reject('test');

    try {
      await deferred.promise;
    } catch (err) {
      expect(err).toBe('test');
    }
  });
});

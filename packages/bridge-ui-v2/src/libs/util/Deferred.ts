import { noop } from './noop';
export class Deferred<T> {
  public promise: Promise<T>;
  public resolve: (value: T | PromiseLike<T>) => void = noop;
  public reject: (reason?: unknown) => void = noop;

  constructor() {
    this.promise = new Promise((resolve, reject) => {
      this.resolve = resolve;
      this.reject = reject;
    });
  }
}

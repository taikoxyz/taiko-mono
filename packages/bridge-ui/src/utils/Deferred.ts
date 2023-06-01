export class Deferred<T> {
  public promise: Promise<T>;
  public resolve: (value?: T) => void;
  public reject: (reason?: unknown) => void;

  constructor() {
    this.promise = new Promise((resolve, reject) => {
      this.resolve = resolve;
      this.reject = reject;
    });
  }
}

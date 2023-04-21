export class Deferred<T> {
  public promise: Promise<T>
  public resolve: (value: T) => void = () => null
  public reject: (reason?: unknown) => void = () => null

  constructor() {
    this.promise = new Promise((resolve, reject) => {
      this.resolve = resolve
      this.reject = reject
    })
  }
}

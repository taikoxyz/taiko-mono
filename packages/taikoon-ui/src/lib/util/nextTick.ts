export function nextTick(fn: () => void) {
  Promise.resolve().then(fn);
}

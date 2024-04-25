export function uid() {
  return Math.floor(Math.random() * Date.now()).toString(16);
}

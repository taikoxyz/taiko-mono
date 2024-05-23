export function classNames(...classes: Array<string | null | undefined>) {
  return classes.filter(Boolean).join(' ');
}

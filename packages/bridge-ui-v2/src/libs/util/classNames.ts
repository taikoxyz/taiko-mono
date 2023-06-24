export function classNames(...classes: Array<Maybe<string>>) {
  return classes.filter(Boolean).join(' ');
}

export function classNames(...classes: Array<string>) {
	return classes.filter(Boolean).join(' ');
}

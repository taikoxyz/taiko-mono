export function truncateDecimal(num: number, decimalPlaces: number) {
	const factor = 10 ** decimalPlaces;
	return Math.floor(num * factor) / factor;
}

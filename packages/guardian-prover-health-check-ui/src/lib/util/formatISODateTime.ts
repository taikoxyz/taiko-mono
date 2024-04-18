export function formatISODateTime(isoDate: string): string {
	const date = new Date(isoDate);

	const pad = (num: number) => num.toString().padStart(2, '0');

	const year = date.getFullYear();
	const month = pad(date.getMonth() + 1);
	const day = pad(date.getDate());
	const hours = pad(date.getHours());
	const minutes = pad(date.getMinutes());

	return `${year}-${month}-${day} ${hours}:${minutes}`;
}

export async function loadGuardians(): Promise<{ [address: string]: string }> {
	const network = import.meta.env.VITE_NETWORK_CONFIG;
	if (!network)
		throw new Error('Network not configured. Please set VITE_NETWORK_CONFIG in .env file.');
	const path = `/config/${network}/guardians.json`;
	const response = await fetch(path);
	if (!response.ok) {
		throw new Error(`Failed to load ${path}: ${response.statusText}`);
	}
	return response.json();
}

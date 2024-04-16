export async function getPseudonym(address: string): Promise<string> {
    const guardians = await loadGuardians();
    const pseudonym = guardians[address] === '-' ? "Unknown" : guardians[address];;

    return pseudonym
}

async function loadGuardians(): Promise<{ [address: string]: string }> {
    const network = import.meta.env.VITE_NETWORK_CONFIG;
    if (!network) throw new Error('Network not configured. Please set VITE_NETWORK_CONFIG in .env file.');
    const path = `/config/${network}/guardians.json`; // adjust path as needed
    const response = await fetch(path);
    if (!response.ok) {
        throw new Error(`Failed to load ${path}: ${response.statusText}`);
    }
    return response.json();
}
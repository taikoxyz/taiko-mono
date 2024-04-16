import { loadGuardians } from './loadConfiguredGuardians';

export async function getPseudonym(address: string): Promise<string> {
	const guardians = await loadGuardians();
	const pseudonym = guardians[address] === '-' ? 'Unknown' : guardians[address];

	return pseudonym;
}

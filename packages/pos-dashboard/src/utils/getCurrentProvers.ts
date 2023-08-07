import type { Prover, ProversResp } from '../domain/prover';

export default async function getCurrentProvers(
  eventIndexerApiUrl?: string,
): Promise<Array<Prover>> {
  const response = await fetch(`${eventIndexerApiUrl}/currentProvers`);
  const data = (await response.json()) as ProversResp;

  return data.provers || [];
}

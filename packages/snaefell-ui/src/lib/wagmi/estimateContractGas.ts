import { getConnectorClient } from '@wagmi/core';
import { estimateContractGas as viemEstimateContractGas } from 'viem/actions';

import getConfig from './getConfig';

export default async function estimateContractGas(params: Parameters<typeof viemEstimateContractGas>[1]) {
  const { config } = getConfig();
  const client = await getConnectorClient(config);

  return await viemEstimateContractGas(client, params);
}

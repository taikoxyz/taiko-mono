import { getConnectorClient } from '@wagmi/core';
import { getLogs as viemGetLogs } from 'viem/actions';

import getConfig from './getConfig';
export default async function getLogs(params: Parameters<typeof viemGetLogs>[1]) {
  const config = getConfig();
  const client = await getConnectorClient(config);

  return await viemGetLogs(client, params);
}

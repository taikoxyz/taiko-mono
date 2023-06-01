import type { providers } from 'ethers';

import type { ChainID } from './chain';

export type RecordProviders = Record<ChainID, providers.StaticJsonRpcProvider>;

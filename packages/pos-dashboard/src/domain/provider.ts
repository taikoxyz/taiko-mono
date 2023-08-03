import type { providers } from 'ethers';

import type { ChainID } from './chain';

export type ProvidersRecord = Record<ChainID, providers.StaticJsonRpcProvider>;

import { PUBLIC_RELAYER_URL } from '$env/static/public';

import { RelayerAPIService } from './RelayerAPIService';

export const relayerApiService = new RelayerAPIService(PUBLIC_RELAYER_URL);

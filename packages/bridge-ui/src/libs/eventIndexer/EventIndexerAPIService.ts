import axios from 'axios';
import type { Address } from 'viem';

import { apiService } from '$config';
import type { ChainID } from '$libs/chain';
import { getLogger } from '$libs/util/logger';

import type { EventIndexerAPI, EventIndexerAPIRequestParams, EventIndexerAPIResponse, PaginationParams } from './types';

const log = getLogger('EventIndexerAPIService');

export class EventIndexerAPIService implements EventIndexerAPI {
  private readonly baseUrl: string;

  constructor(baseUrl: string) {
    log('eventIndexer service instantiated');

    this.baseUrl = baseUrl.replace(/\/$/, '');
  }

  async getNftsByAddress(params: EventIndexerAPIRequestParams): Promise<EventIndexerAPIResponse> {
    const requestURL = `${this.baseUrl}/nftsByAddress`;

    try {
      log('Fetching from API with params', params);

      const response = await axios.get<EventIndexerAPIResponse>(requestURL, {
        params,
        timeout: apiService.timeout,
      });

      if (!response || response.status >= 400) throw response;

      log('Events form API', response.data);

      return response.data;
    } catch (error) {
      console.error(error);
      log('Failed to fetch from API', error);
      throw new Error('could not fetch transactions from API', {
        cause: error,
      });
    }
  }

  async getAllNftsByAddressFromAPI(
    address: Address,
    chainID: ChainID,
    paginationParams: PaginationParams,
  ): Promise<EventIndexerAPIResponse> {
    const params = {
      address,
      chainID,
      ...paginationParams,
    };
    const response = await this.getNftsByAddress(params);

    // todo: filter and cleanup?

    return response;
  }
}

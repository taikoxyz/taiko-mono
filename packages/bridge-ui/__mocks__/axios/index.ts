import type { AxiosRequestConfig } from 'axios';

const axios = {
  get: jest.fn<Promise<unknown>, [string, AxiosRequestConfig<unknown>]>(),
};

export default axios;

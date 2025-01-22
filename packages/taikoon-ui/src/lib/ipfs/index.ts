import getMetadata from './getMetadata';
import httpGet from './httpGet';

const IPFS = {
  get: httpGet,
  getMetadata,
};

export default IPFS;

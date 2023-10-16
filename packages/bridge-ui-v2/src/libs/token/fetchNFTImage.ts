import { getLogger } from '$libs/util/logger';

import type { Token } from './types';

const log = getLogger('libs:token:fetchNFTImage');

export const fetchNFTImage = (token: Token) => {
  log('fetching image for', token);
  return null;
};

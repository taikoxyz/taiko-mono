export const safeParseUrl = (uri: string) => {
  const IPFS_PREFIX = 'ipfs://';

  if (uri && uri.startsWith(IPFS_PREFIX)) {
    // todo: multiple configurable ipfs gateways as fallback
    const ipfsPath = uri.replace(IPFS_PREFIX, '');
    return `https://ipfs.io/ipfs/${ipfsPath}`;
  }

  return uri;
};

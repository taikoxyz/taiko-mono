export enum IPFSGateway {
  IPFS_IO = 'https://ipfs.io/ipfs/',
  CLOUDFLARE_IPFS_COM = 'https://cloudflare-ipfs.com/ipfs/',
}

export const safeParseUrl = (uri: string, gateway: IPFSGateway | string = IPFSGateway.IPFS_IO) => {
  const IPFS_PREFIX = 'ipfs://';

  if (uri && uri.startsWith(IPFS_PREFIX)) {
    const ipfsPath = uri.replace(IPFS_PREFIX, '');
    return `${gateway}${ipfsPath}`;
  }
  return uri;
};

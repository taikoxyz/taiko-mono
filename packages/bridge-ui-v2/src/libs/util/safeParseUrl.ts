export const safeParseUrl = (uri: string) => {
  if (uri && uri.startsWith('ipfs://')) {
    // todo: multiple configurable ipfs gateways as fallback
    return `https://ipfs.io/ipfs/${uri.slice(7)}`;
  }
  return uri;
};

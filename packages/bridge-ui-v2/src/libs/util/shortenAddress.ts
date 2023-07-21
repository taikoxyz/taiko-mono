export const shortenAddress = (address: string, charsStart = 6, charsEnd = 4, sep = '…') => {
  if (!address) return '0x';
  return [address.slice(0, charsStart), address.slice(-charsEnd)].join(sep);
};

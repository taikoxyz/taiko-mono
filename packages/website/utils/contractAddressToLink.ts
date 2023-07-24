export function contractAddressToLink(
  baseUrl: string,
  contractAddress: string
): string {
  return `${baseUrl}/address/${contractAddress}`;
}

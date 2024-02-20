declare module 'ethereum-address' {
  export function isAddress(address: string): boolean;
  export function isChecksumAddress(address: string): boolean;
}

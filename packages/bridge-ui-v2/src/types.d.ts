declare module 'ethereum-address' {
  export function isAddress(address: string): boolean;
  export function isChecksumAddress(address: string): boolean;
}

declare module '$bridgeConfig' {
  export const routingContractsMap: RoutingMap
}

declare module '$chainConfig' {
  export const chainConfig: ChainConfigMap
}

declare module '$relayerConfig' {
  export const customToken: Token[]
}

declare module '$customToken' {
  export const configuredRelayer: RelayerConfig[]
}

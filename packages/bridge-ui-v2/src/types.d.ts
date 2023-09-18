import type { RoutingMap } from "$libs/bridge"
import type { ChainConfigMap } from "$libs/chain"
import type { RelayerConfig } from "$libs/relayer"
import type { Token } from "$libs/token"

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
  export const configuredRelayer: RelayerConfig[]
}

declare module '$customToken' {
  
  export const customToken: Token[]
}

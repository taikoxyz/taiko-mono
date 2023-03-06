import { writable } from "svelte/store";
import { Client, configureChains, createClient } from "@wagmi/core";
import type { ethers } from "ethers";
import { mainnet, taiko } from "../domain/chain";
import { publicProvider } from "@wagmi/core/providers/public";
import { jsonRpcProvider } from "@wagmi/core/providers/jsonRpc";
import { MetaMaskConnector } from "@wagmi/core/connectors/metaMask";
import { CoinbaseWalletConnector } from "@wagmi/core/connectors/coinbaseWallet";
import { WalletConnectConnector } from "@wagmi/core/connectors/walletConnect";

export const wagmiClient = writable<Client>();

/**
 * Configure the different chains, mainnet and taiko, based on
 * our custom RPC providers, and create a wagmi client.
 */
export function setWagmiClient(
  providerMap: Map<number, ethers.providers.JsonRpcProvider>
) {
  const { chains, provider } = configureChains(
    [mainnet, taiko],
    [
      publicProvider(),
      jsonRpcProvider({
        rpc: (chain) => ({
          http: providerMap.get(chain.id).connection.url,
        }),
      }),
    ]
  );

  wagmiClient.set(
    createClient({
      provider,
      autoConnect: true,
      connectors: [
        new MetaMaskConnector({
          chains,
        }),
        new CoinbaseWalletConnector({
          chains,
          options: {
            appName: "Taiko Bridge",
          },
        }),
        new WalletConnectConnector({
          chains,
          options: {
            qrcode: true,
          },
        }),
      ],
    })
  );

  return wagmiClient;
}

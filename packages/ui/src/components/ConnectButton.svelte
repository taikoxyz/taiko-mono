<script lang="ts">
  import { failureToast, successToast } from "./toasts/toasts";
  import { currentAddress } from "../store/currentAddress";
  import { push } from "svelte-spa-router";
  import { ethers } from "ethers";
  import { signer } from "../store/signer";
  import { chainId } from "../store/chainId";
  import { provider as providerStore } from "../store/provider";

  const connect = async () => {
    try {
      const provider = (
        window as any as { ethereum: ethers.providers.ExternalProvider }
      ).ethereum;

      const addresses = await provider.request({
        method: "eth_requestAccounts",
      });

      const block = await provider.request({
        method: "eth_getBlockByNumber",
        params: ["0x86", false],
      });

      console.log(block);
      currentAddress.set(addresses[0]);
      providerStore.set(provider);
      const s = new ethers.providers.Web3Provider(provider).getSigner();
      signer.set(s);
      const c = await s.getChainId();
      chainId.set(c);
      successToast("Successfully connected!");
    } catch (e) {
      failureToast("Could not connect to Ethereum provider");
    }
  };
</script>

{#if $currentAddress}
  <div class="cursor-pointer" on:click={async () => await push("/home")}>
    {$currentAddress}
  </div>
{:else}
  <button class="btn btn-secondary" on:click={async () => await connect()}
    >Connect</button
  >
{/if}

<script lang="ts">
  import { _ } from "svelte-i18n";
  import { fetchSigner, switchNetwork } from "@wagmi/core";
  import { CHAIN_MAINNET, CHAIN_TKO } from "../../domain/chain";
  import type { Chain } from "../../domain/chain";
  import { isSwitchEthereumChainModalOpen } from "../../store/modal";
  import Modal from "./Modal.svelte";
  import { signer } from "../../store/signer";
  import { errorToast, successToast } from "../../utils/toast";

  const switchChain = async (chain: Chain) => {
    try {
      await switchNetwork({
        chainId: chain.id,
      });
      const wagmiSigner = await fetchSigner();

      signer.set(wagmiSigner);
      isSwitchEthereumChainModalOpen.set(false);
      successToast("Successfully switched chain");
    } catch (e) {
      console.error(e);
      errorToast("Error switching ethereum chain");
    }
  };
</script>

<Modal
  title={$_("switchChainModal.title")}
  isOpen={$isSwitchEthereumChainModalOpen}
>
  <div class="w-100 text-center px-4">
    <span class="font-light text-sm">{$_("switchChainModal.subtitle")}</span>
    <div class="py-8 space-y-4 flex flex-col">
      <button
        class="btn btn-dark-5 h-[60px] text-base"
        on:click={async () => {
          await switchChain(CHAIN_MAINNET);
        }}
      >
        <svelte:component this={CHAIN_MAINNET.icon} /><span class="ml-2"
          >{CHAIN_MAINNET.name}</span
        >
      </button>
      <button
        class="btn btn-dark-5 h-[60px] text-base"
        on:click={async () => {
          await switchChain(CHAIN_TKO);
        }}
      >
        <svelte:component this={CHAIN_TKO.icon} /><span class="ml-2"
          >{CHAIN_TKO.name}</span
        >
      </button>
    </div>
  </div>
</Modal>

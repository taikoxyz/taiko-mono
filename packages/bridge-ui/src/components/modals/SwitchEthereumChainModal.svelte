<script lang="ts">
  import { _ } from "svelte-i18n";
  import { CHAIN_MAINNET, CHAIN_TKO } from "../../domain/chain";
  import type { Chain } from "../../domain/chain";
  import { switchEthereumChain } from "../../utils/switchEthereumChain";
  import { isSwitchEthereumChainModalOpen } from "../../store/modal";
  import { ethereum } from "../../store/ethereum";
  import Modal from "./Modal.svelte";
  import { ethers } from "ethers";
  import { signer } from "../../store/signer";

  const switchChain = async (chain: Chain) => {
    await switchEthereumChain($ethereum, CHAIN_TKO);
    const provider = new ethers.providers.Web3Provider(window.ethereum);
    await provider.send("eth_requestAccounts", []);

    signer.set(provider.getSigner());
    isSwitchEthereumChainModalOpen.set(false);
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

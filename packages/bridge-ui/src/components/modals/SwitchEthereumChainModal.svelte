<script lang="ts">
  import { _ } from "svelte-i18n";
  import { CHAIN_MAINNET, CHAIN_TKO } from "../../domain/chain";
  import { switchEthereumChain } from "../../utils/switchEthereumChain";
  import { isSwitchEthereumChainModalOpen } from "../../store/modal";
  import { ethereum } from "../../store/ethereum";
  import Modal from "./Modal.svelte";
</script>

<Modal title={$_('switchChainModal.title')} isOpen={$isSwitchEthereumChainModalOpen}>
  <div class="w-100 text-center px-4">
    <span class="font-light text-sm">{$_('switchChainModal.subtitle')}</span>
    <div class="py-8 space-y-4 flex flex-col">
      <button
        class="btn btn-dark-5 h-[60px] text-base"
        on:click={async () => {
          await switchEthereumChain($ethereum, CHAIN_MAINNET);
          isSwitchEthereumChainModalOpen.set(false);
        }}>
        <svelte:component this={CHAIN_MAINNET.icon} /><span class="ml-2">{CHAIN_MAINNET.name}</span>
      </button>
      <button
        class="btn btn-dark-5 h-[60px] text-base"
        on:click={async () => {
          await switchEthereumChain($ethereum, CHAIN_TKO);
          isSwitchEthereumChainModalOpen.set(false);
        }}>
        <svelte:component this={CHAIN_TKO.icon} /><span class="ml-2">{CHAIN_TKO.name}</span>
        </button>
    </div>
  </div>
</Modal>

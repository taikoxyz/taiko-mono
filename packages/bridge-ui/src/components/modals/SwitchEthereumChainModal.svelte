<script lang="ts">
  import { CHAIN_MAINNET, CHAIN_TKO } from "../../domain/chain";
  import { switchEthereumChain } from "../../utils/switchEthereumChain";
  import { isSwitchEthereumChainModalOpen } from "../../store/modal";
  import { ethereum } from "../../store/ethereum";
  import Modal from "./Modal.svelte";
</script>

<Modal title={"Switch Ethereum Chain"} isOpen={$isSwitchEthereumChainModalOpen}>
  <div class="w-100 text-center p-4">
    Your current network is not supported. Please change to one of:
    <button
      class="btn btn-accent block btn-block mb-2"
      on:click={async () => {
        await switchEthereumChain($ethereum, CHAIN_MAINNET);
        isSwitchEthereumChainModalOpen.set(false);
      }}
    >
      <svelte:component this={CHAIN_MAINNET.icon} />{CHAIN_MAINNET.name}</button
    >
    <button
      class="btn btn-accent block btn-block"
      on:click={async () => {
        await switchEthereumChain($ethereum, CHAIN_TKO);
        isSwitchEthereumChainModalOpen.set(false);
      }}
    >
      <svelte:component this={CHAIN_TKO.icon} />{CHAIN_TKO.name}</button
    >
  </div>
</Modal>

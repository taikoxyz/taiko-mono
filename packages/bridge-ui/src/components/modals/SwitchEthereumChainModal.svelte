<script lang="ts">
  import { CHAIN_MAINNET, CHAIN_TKO } from "../../domain/chain";
  import { switchEthereumChain } from "../../utils/switchEthereumChain";
  import { isSwitchEthereumChainModalOpen } from "../../store/modal";
  import { ethereum } from "../../store/ethereum";
  import Modal from "./Modal.svelte";
</script>

<Modal title={"Switch Ethereum Chain"} isOpen={$isSwitchEthereumChainModalOpen}>
  <div>
    Your current network is not supported. Please change to one of:
    <button
      class="btn btn-accent"
      on:click={async () => {
        await switchEthereumChain($ethereum, CHAIN_MAINNET);
        isSwitchEthereumChainModalOpen.set(false);
      }}>{CHAIN_MAINNET.name}</button
    >
    <button
      class="btn btn-accent"
      on:click={async () => {
        await switchEthereumChain($ethereum, CHAIN_TKO);
        isSwitchEthereumChainModalOpen.set(false);
      }}>{CHAIN_TKO.name}</button
    >
  </div>
</Modal>

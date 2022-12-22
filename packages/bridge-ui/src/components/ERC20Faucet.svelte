<script lang="ts">
  import { ethers } from "ethers";
  import { HORSE } from "../domain/token";
  import { pendingTransactions } from "../store/transactions";
  import { signer } from "../store/signer";
  import { errorToast, successToast } from "../utils/toast";
  import { _ } from "svelte-i18n";
  import { Funnel } from "svelte-heros-v2";
  import MintableERC20 from "../constants/abi/MintableERC20";
  import { fromChain } from "../store/chain";
  import { switchNetwork } from "@wagmi/core";
  import { CHAIN_MAINNET } from "../domain/chain";
  import Tooltip from "./Tooltip.svelte";
  import TooltipModal from "./modals/TooltipModal.svelte";
  import { token } from "../store/token";

  export let onMint: () => Promise<void>;

  let tooltipOpen: boolean = false;

  async function mint() {
    try {
      if ($fromChain.id !== HORSE.addresses[0].chainId) {
        await switchNetwork({
          chainId: CHAIN_MAINNET.id,
        });
      }
      const contract = new ethers.Contract(
        HORSE.addresses[0].address,
        MintableERC20,
        $signer
      );

      const tx = await contract.mint(ethers.utils.parseEther("1000"));
      pendingTransactions.update((store) => {
        store.push(tx);
        return store;
      });

      successToast($_("toast.transactionSent"));
      await $signer.provider.waitForTransaction(tx.hash, 1);

      await onMint();
    } catch (e) {
      console.log(e);
      errorToast($_("toast.errorSendingTransaction"));
    }
  }
</script>

<button class="btn" on:click={mint}>
  <Funnel class="mr-2" /> Faucet
</button>
<Tooltip />

<TooltipModal title="{$token.symbol} Faucet" bind:isOpen={tooltipOpen}>
  <span slot="body">
    <p class="text-left">
      You can request 1000 {$token.symbol}. {$token.symbol} is only available to
      be minted on Ethereum A1. If you are on Taiko A1, your network will be changed
      first. You must have a small amount of ether in your Ethereum A1 wallet to
      send the transaction.
    </p>
  </span>
</TooltipModal>

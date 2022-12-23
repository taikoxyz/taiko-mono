<script lang="ts">
  import { BigNumber, ethers, logger, Signer } from "ethers";
  import { HORSE } from "../../domain/token";
  import { pendingTransactions } from "../../store/transactions";
  import { signer } from "../../store/signer";
  import { errorToast, successToast } from "../../utils/toast";
  import { _ } from "svelte-i18n";
  import MintableERC20 from "../../constants/abi/MintableERC20";
  import { fromChain } from "../../store/chain";
  import { fetchSigner, switchNetwork } from "@wagmi/core";
  import { CHAIN_MAINNET } from "../../domain/chain";
  import Modal from "./Modal.svelte";
  import { onMount } from "svelte";
  import { token } from "../../store/token";

  export let isOpen: boolean = false;
  export let onMint: () => Promise<void>;

  let disabled: boolean = true;

  onMount(async () => {
    isBtnDisabled($signer);
  });

  $: isBtnDisabled($signer).catch((e) => console.error(e));

  async function isBtnDisabled(signer: Signer) {
    if (!signer) return;
    const balance = await signer.getBalance();
    const contract = new ethers.Contract(
      HORSE.addresses[0].address,
      MintableERC20,
      signer
    );

    const gas = await contract.estimateGas.mint(
      ethers.utils.parseEther("1000")
    );
    const gasPrice = await signer.getGasPrice();
    const estimatedGas = BigNumber.from(gas).mul(gasPrice);
    if (balance.lt(estimatedGas)) {
      disabled = true;
    } else {
      disabled = false;
    }
  }

  async function mint() {
    try {
      if ($fromChain.id !== HORSE.addresses[0].chainId) {
        await switchNetwork({
          chainId: CHAIN_MAINNET.id,
        });
        const wagmiSigner = await fetchSigner();

        signer.set(wagmiSigner);
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
      isOpen = false;
      await $signer.provider.waitForTransaction(tx.hash, 1);

      await onMint();
    } catch (e) {
      console.log(e);
      errorToast($_("toast.errorSendingTransaction"));
    }
  }
</script>

<Modal title={"ERC20 Faucet"} bind:isOpen>
  You can request 1000 {$token.symbol}. {$token.symbol} is only available to be minted
  on Ethereum A1. If you are on Taiko A1, your network will be changed first. You
  must have a small amount of ETH in your Ethereum A1 wallet to send the transaction.
  <br />
  <button
    class="btn btn-dark-5 h-[60px] text-base"
    {disabled}
    on:click={async () => {
      await mint();
    }}
  >
    {#if disabled}
      Insufficient ETH
    {:else}
      Mint
    {/if}
  </button>
</Modal>

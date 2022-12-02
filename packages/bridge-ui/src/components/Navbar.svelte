<script lang="ts">
  import Connect from "./buttons/Connect.svelte";
  import Logo from "./icons/Logo.svelte";
  import { signer } from "../store/signer";
  import AddressDropdown from "./AddressDropdown.svelte";
  import type {
    BridgeTransaction,
    Transactioner,
  } from "../domain/transactions";
  import type { Signer } from "ethers";
  import { fromChain } from "../store/chain";

  export let transactioner: Transactioner;
  let transactions: BridgeTransaction[];

  $: getTransactions($signer);

  async function getTransactions(signer: Signer) {
    if (!signer) return;
    transactions = await transactioner.GetAllByAddress(
      await signer.getAddress(),
      $fromChain.id
    );
  }
</script>

<nav class="navbar h-[125px] py-8 px-32">
  <div class="navbar-end justify-start">
    <Logo />
  </div>
  <div class="navbar-end">
    {#if $signer}
      <AddressDropdown {transactions} />
    {:else}
      <Connect />
    {/if}
  </div>
</nav>

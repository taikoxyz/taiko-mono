<script lang="ts">
  import { ETH } from "../../domain/token";
  import { Trash } from "svelte-heros-v2";
  import { signer } from "../../store/signer";
  import { token as tokenStore } from "../../store/token";
  import { userTokens, userTokenStore } from "../../store/userTokenStore";
  import Erc20 from "../icons/ERC20.svelte";
  import Modal from "../modals/Modal.svelte";
  import { LottiePlayer } from "@lottiefiles/svelte-lottie-player";

  export let showAddressField = false;
  export let addERC20;
  export let loading = false;

  let customTokens = [];
  userTokens.subscribe(tokens => customTokens = tokens);

  async function remove(token) {
    const address = await $signer.getAddress();
    const updatedTokensList = $userTokenStore.RemoveToken(token, address);
    userTokens.set(updatedTokensList);
    tokenStore.set(ETH);
  }
</script>

<Modal title="Add custom ERC20" bind:isOpen={showAddressField}>
  <form class="flex h-full min-h-tooltip-modal w-full flex-col justify-between" on:submit|preventDefault={addERC20}>
    <input
      type="text"
      placeholder="Enter valid ERC20 Address"
      class="input input-primary bg-dark-2 input-md md:input-lg w-full focus:ring-0 my-4"
      name="customTokenAddress"
    />
    {#if loading}
      <button class="btn" disabled={true}>
        <LottiePlayer
          src="/lottie/loader.json"
          autoplay={true}
          loop={true}
          controls={false}
          renderer="svg"
          background="transparent"
          height={26}
          width={26}
          controlsLayout={[]}
        />
      </button>
      {:else}
        <button class="btn" type="submit">Add New</button>
      {/if}
  </form>
  {#if customTokens.length > 0}
  <div class="flex h-full w-full flex-col justify-between bg-none mt-6">
    <h3>Tokens already added</h3>
    {#each customTokens as t}
      <div class="flex items-center justify-between">
        <div class="flex items-center">
          <Erc20 />
          <span class="bg-transparent">{t.symbol}</span>
        </div>
        <button class="btn btn-sm" on:click={() => remove(t)}>
          <Trash />
        </button>
      </div>
    {/each}
  </div>
  {/if}
</Modal>
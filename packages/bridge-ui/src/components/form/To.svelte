<script lang="ts">
  import ButtonWithTooltip from '../ButtonWithTooltip.svelte';
  import TooltipModal from '../modals/TooltipModal.svelte';

  export let showTo: boolean = false;
  export let to: string = '';

  let tooltipOpen: boolean = false;
</script>

<div class="label flex flex-row justify-between items-center">
  <label for="to-address">
    <ButtonWithTooltip onClick={() => (tooltipOpen = true)}>
      <span slot="buttonText">Custom Recipient</span>
    </ButtonWithTooltip>
  </label>

  <input
    id="to-address"
    type="checkbox"
    class="toggle rounded-full duration-300"
    on:click={() => {
      showTo = !showTo;
    }}
    bind:checked={showTo} />
</div>

{#if showTo}
  <input
    type="text"
    class="input input-primary bg-dark-2 input-md md:input-lg w-full focus:ring-0 border-dark-2"
    placeholder="0x..."
    name="to"
    bind:value={to} />
{/if}

<TooltipModal title="Custom Recipient" bind:isOpen={tooltipOpen}>
  <span slot="body">
    <p class="text-left">
      You can set a custom address as the recipient of your funds, instead of
      your current wallet address.
    </p>
  </span>
</TooltipModal>

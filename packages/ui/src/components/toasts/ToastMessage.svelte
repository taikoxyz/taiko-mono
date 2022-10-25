<script lang="ts">
  import type { SvelteComponent } from "svelte";
  export let message: string;
  export let icon: typeof SvelteComponent = null;
  const TRUNCATE_AFTER_LENGTH: number = 110;
  const messageIsTooLong: boolean = message.length > TRUNCATE_AFTER_LENGTH;

  function truncate(message: string) {
    return messageIsTooLong
      ? message.substring(0, TRUNCATE_AFTER_LENGTH - 1) + "..."
      : message;
  }
</script>

<div class="align-center justify-center p-3 px-0 text-left">
  <div class="w-100">
    {#if icon}
      <div class="inline-block align-middle {messageIsTooLong ? 'pb-3' : ''}">
        <svelte:component this={icon} />
      </div>
    {/if}
    <p
      class="pl-3 {messageIsTooLong
        ? 'pt-3'
        : ''} inline-block w-11/12 text-xs font-medium text-gray-100"
      title={messageIsTooLong ? message : ""}
    >
      {truncate(message)}
    </p>
  </div>
</div>

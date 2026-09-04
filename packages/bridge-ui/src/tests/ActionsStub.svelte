<!--
  Stands in for the Actions bar in ConfirmationStep tests. One button per action the real
  component exposes, so a test can start a bridge without going through the approval checks.
  Every prop the real component takes is declared and rendered, so Svelte warns about neither
  an unknown prop nor an unused export.
-->
<script lang="ts">
  export let approve: () => Promise<void>;
  export let bridge: () => Promise<void>;
  export let resetApproval: () => Promise<void>;
  export let approving = false;
  export let bridging = false;
  export let checking = false;
  export let resetting = false;
</script>

<button data-testid="stub-approve" on:click={approve}>approve</button>
<button data-testid="stub-bridge" on:click={bridge}>bridge</button>
<button data-testid="stub-reset-approval" on:click={resetApproval}>reset</button>
<span
  data-testid="stub-flags"
  data-approving={approving}
  data-bridging={bridging}
  data-checking={checking}
  data-resetting={resetting} />

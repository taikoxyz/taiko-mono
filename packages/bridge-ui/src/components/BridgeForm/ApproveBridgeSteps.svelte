<script lang="ts">
  export let requiresApproval: boolean = false;
  export let hasAmount: boolean = false;
  export let computing: boolean = false;
  export let approving: boolean = false;

  $: dataContent = approving
    ? '…'
    : !hasAmount || computing
    ? '?'
    : !requiresApproval
    ? '✓'
    : null;

  $: isApproved = !computing && dataContent === '✓';

  $: approveLabel = approving
    ? 'Approving...'
    : isApproved
    ? 'Approved'
    : 'Approval required';

  $: bridgeLabel =
    !computing && dataContent === '✓' ? 'Ready to bridge' : 'Bridge';
</script>

<ul class="steps w-full">
  <li
    data-content={dataContent}
    class="step step-neutral"
    class:step-accent={isApproved}>
    {approveLabel}
  </li>
  <li class="step step-neutral">
    {bridgeLabel}
  </li>
</ul>

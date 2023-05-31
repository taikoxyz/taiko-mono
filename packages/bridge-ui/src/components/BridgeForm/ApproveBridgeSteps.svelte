<script lang="ts">
  export let requiresAllowance: boolean = false;
  export let hasAmount: boolean = false;
  export let computingAllowance: boolean = false;
  export let pendingTransaction: boolean = false;

  const LOADING = '●';
  const UNKNOWN = '?';
  const DONE = '✓';

  $: approving = pendingTransaction && requiresAllowance;

  $: bridging = pendingTransaction && !requiresAllowance;

  $: approvalContent = approving
    ? LOADING
    : !hasAmount || computingAllowance
    ? UNKNOWN // at this point we still don't know whether we need approval
    : !requiresAllowance
    ? DONE
    : null;

  $: isApproved = !computingAllowance && approvalContent === DONE;

  $: approveLabel = approving
    ? 'Approving…'
    : isApproved
    ? 'Approved'
    : 'Approve token';

  $: bridgeContent = bridging ? LOADING : null;

  $: bridgeLabel = bridging
    ? 'Bridging…'
    : !computingAllowance && approvalContent === DONE
    ? 'Bridge'
    : 'Bridge';
</script>

<ul class="steps w-full">
  <li
    data-content={approvalContent}
    class="step step-neutral"
    class:step-accent={isApproved}>
    {approveLabel}
  </li>
  <li data-content={bridgeContent} class="step step-neutral">
    {bridgeLabel}
  </li>
</ul>

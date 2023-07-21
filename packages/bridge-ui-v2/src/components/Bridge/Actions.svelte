<script>
  import { noop } from 'svelte/internal';
  import { t } from 'svelte-i18n';

  import { Button } from '$components/Button';

  export let approve = noop;
  export let bridge = noop;

  let approving = false;
  let bridging = false;

  function onApproveClick() {
    approving = true;
    approve().finally(() => {
      approving = false;
    });
  }

  function onBridgeClick() {
    bridging = true;
    bridge().finally(() => {
      bridging = false;
    });
  }

  $: showSteps = false;

  $: loading = approving || bridging;
</script>

<Button type="primary" class="px-[28px] py-[14px] rounded-full w-full" on:click={onBridgeClick}>
  <span class="body-bold">{$t('bridge.button.bridge')}</span>
</Button>

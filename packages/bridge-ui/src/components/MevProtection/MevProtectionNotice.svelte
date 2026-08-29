<script lang="ts">
  import { t } from 'svelte-i18n';

  import { Alert } from '$components/Alert';
  import { ActionButton } from '$components/Button';
  import { enablePrivateRpc, getPrivateRpc, hasEnabledPrivateRpc } from '$libs/mev';
  import { getLogger } from '$libs/util/logger';

  export let chainId: number;

  const log = getLogger('MevProtectionNotice');

  let enabling = false;
  let accepted = false;
  let failed = false;

  $: privateRpc = getPrivateRpc(chainId);

  $: alreadyEnabled = hasEnabledPrivateRpc(chainId);

  const enable = async () => {
    enabling = true;
    failed = false;
    try {
      await enablePrivateRpc(chainId);
      accepted = true;
    } catch (err) {
      // Wallets may refuse to add an endpoint, and the user may simply reject the prompt. Claiming
      // still works over their own RPC, so this never blocks the flow.
      log('could not enable the private relay', err);
      failed = true;
    } finally {
      enabling = false;
    }
  };
</script>

{#if privateRpc && !alreadyEnabled && !accepted}
  <div class="f-col space-y-[12px]">
    <Alert type="warning" forceColumnFlow>
      {$t('mev_protection.description', { values: { relay: privateRpc.name } })}
      <a class="link" href={privateRpc.docsUrl} target="_blank" rel="noreferrer">
        {$t('mev_protection.learn_more')}
      </a>
    </Alert>
    {#if failed}
      <Alert type="error">{$t('mev_protection.failed')}</Alert>
    {/if}
    <ActionButton onPopup priority="secondary" loading={enabling} disabled={enabling} on:click={enable}>
      {$t('mev_protection.enable', { values: { relay: privateRpc.name } })}
    </ActionButton>
  </div>
{/if}

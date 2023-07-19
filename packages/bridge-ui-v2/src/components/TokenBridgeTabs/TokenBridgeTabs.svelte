<script lang="ts">
  import { onDestroy, onMount } from 'svelte';
  import { t } from 'svelte-i18n';

  import { TabButton } from '$components/TabButton';
  import { activeTab, checkIsActive } from '$stores/bridgetabs';

  let isErc20TabActive = false;
  let isNftTabActive = false;

  const unsubscribe = activeTab.subscribe(() => {
    isErc20TabActive = checkIsActive('erc20_tab');
    isNftTabActive = checkIsActive('nft_tab');
  });

  onMount(() => {
    isErc20TabActive = checkIsActive('erc20_tab');
    isNftTabActive = checkIsActive('nft_tab');
  });

  onDestroy(() => {
    unsubscribe();
  });
</script>

<div class="flex">
  <TabButton tabName="erc20_tab">
    {$t('bridge.button.erc20')}
  </TabButton>

  <TabButton tabName="nft_tab">
    {$t('bridge.button.nft')}
  </TabButton>
</div>

<script lang="ts">
  import { t } from 'svelte-i18n';

  import { Card } from '$components/Card';
  import { ChainSelector } from '$components/ChainSelector';
  import { network } from '$stores/network';

  import ListWithDetailsView from './ListWithDetailsView.svelte';
  import TableView from './TableView.svelte';
</script>

<Card class="md:min-w-[524px]" title={$t('activities.title')} text={$t('activities.subtitle')}>
  <div class="space-y-[35px]">
    <ChainSelector label={$t('chain_selector.currently_on')} value={$network} />
    <!-- Small size view  -->
    <div class="md:hidden">
      <ListWithDetailsView />
    </div>

    <!-- Medium size view: desktop and larger -->
    <div class="hidden md:block">
      <TableView />
    </div>
  </div>
</Card>

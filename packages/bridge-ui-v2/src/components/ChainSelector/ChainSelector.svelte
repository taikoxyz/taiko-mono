<script>
  import { EthIcon } from '$components/Icon';
  import { t } from 'svelte-i18n';
</script>

<span>
  <button class="px-2 py-[6px] body-small-regular bg-neutral-background rounded-md min-w-[150px]">
    <div class="flex space-x-2 items-center">
      <i role="img" aria-label={'Chain'}>
        <EthIcon small />
      </i>
      <span>{$t('chain_selector.placeholder')}…</span>
    </div>
  </button>

  <div />
</span>

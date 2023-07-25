<script lang="ts">
  import { createEventDispatcher, onMount } from 'svelte';
  import { t } from 'svelte-i18n';

  import { Tooltip } from '$components/Tooltip';
  import { uid } from '$libs/util/uid';

  let tokenIdInput = '';
  let inputId = `input-${uid()}`;

  const dispatch = createEventDispatcher();

  $: {
    let tokenIds;
    if (tokenIdInput === '') {
      tokenIds = null;
    } else {
      tokenIds = tokenIdInput.split(',').map((id) => Number(id.trim()));
    }
    dispatch('tokenIdUpdate', { tokenIds });
  }
</script>

<div class="f-col space-y-2">
  <div class="f-between-center text-secondary-content">
    <label class="body-regular" for={inputId}>{$t('inputs.nft.token_id.label')}</label>
  </div>
  <div class="relative f-items-center">
    <input
      id={inputId}
      class="w-full input-box outline-none py-3 px-6 pr-[52px] body-regular placeholder:text-tertiary-content"
      placeholder={$t('inputs.nft.token_id.placeholder')}
      bind:value={tokenIdInput} />
    <Tooltip class="absolute right-6" position="top">Check our guide if you need help finding your token ID</Tooltip>
  </div>
</div>

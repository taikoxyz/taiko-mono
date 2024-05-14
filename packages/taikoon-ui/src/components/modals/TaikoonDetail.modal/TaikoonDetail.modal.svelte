<script lang="ts">
  import { getContext } from 'svelte';
  import { t } from 'svelte-i18n';

  import { InfoRow } from '$components/core/InfoRow';
  import { NftRenderer } from '$components/NftRenderer';
  import Token from '$lib/token';
  import { classNames } from '$lib/util/classNames';
  import { shortenAddress } from '$lib/util/shortenAddress';
  import type { ITaikoonDetail } from '$stores/taikoonDetail';
  import { Modal, ModalBody, ModalTitle } from '$ui/Modal';

  $: shortenedAddress = '...';

  const taikoonDetailState = getContext<ITaikoonDetail>('taikoonDetail');

  async function updateShortenedAddress() {
    if ($taikoonDetailState.tokenId < 0) return;
    const owner = await Token.ownerOf($taikoonDetailState.tokenId);
    shortenedAddress = await shortenAddress(owner);
  }

  $: $taikoonDetailState.tokenId, updateShortenedAddress();

  const modalClasses = classNames('items-center', 'justify-center');

  const nftWrapperClasses = 'rounded-3xl m-6 overflow-hidden';
</script>

<Modal open={$taikoonDetailState.isModalOpen} class={modalClasses}>
  <ModalTitle class="px-10">Taikoon #{$taikoonDetailState.tokenId}</ModalTitle>

  <ModalBody>
    <div class={nftWrapperClasses}>
      <NftRenderer tokenId={$taikoonDetailState.tokenId} />
    </div>
    <InfoRow
      class="px-6"
      label={$t('content.collection.ownedBy')}
      value={shortenedAddress}
      href={'/collection/${taikoon.owner}'} />
  </ModalBody>
</Modal>

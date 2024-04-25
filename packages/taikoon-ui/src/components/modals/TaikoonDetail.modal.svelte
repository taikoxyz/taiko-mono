<script lang="ts">
  import { getContext } from 'svelte';

  import { InfoRow } from '$components/core/InfoRow';
  import { NftRenderer } from '$components/NftRenderer';
  import Token from '$lib/token';
  import { shortenAddress } from '$lib/util/shortenAddress';
  import { Modal, ModalBody, ModalTitle } from '$ui/Modal';

  $: shortenedAddress = '...';

  const taikoonDetailState = getContext('taikoonDetail');

  async function updateShortenedAddress() {
    if ($taikoonDetailState.tokenId < 0) return;
    const owner = await Token.ownerOf($taikoonDetailState.tokenId);
    shortenedAddress = await shortenAddress(owner);
  }

  $: $taikoonDetailState.tokenId, updateShortenedAddress();
</script>

<Modal open={$taikoonDetailState.isModalOpen} class="items-center justify-center">
  <ModalTitle class="px-10">Taikoon #{$taikoonDetailState.tokenId}</ModalTitle>

  <ModalBody>
    <div class="rounded-3xl m-6 overflow-hidden">
      <NftRenderer tokenId={$taikoonDetailState.tokenId} />
    </div>
    <InfoRow class="px-6" label="Owned by" value={shortenedAddress} href={'/collection/${taikoon.owner}'} />
  </ModalBody>
</Modal>

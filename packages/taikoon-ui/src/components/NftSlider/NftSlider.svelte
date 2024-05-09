<script lang="ts">
  import { IconButton } from '$components/core/IconButton';
  import { NftRenderer } from '$components/NftRenderer';

  import {
    carouselItemClasses,
    carouselWrapperClasses,
    leftIconButtonClasses,
    rightIconButtonClasses,
    wrapperClasses,
  } from './classes';

  export let tokenIds: number[] = [];

  $: activeTokenId = tokenIds[0] || 1;

  function handleLeftClick() {
    const index = tokenIds.indexOf(activeTokenId);
    if (index === 0) {
      activeTokenId = tokenIds[tokenIds.length - 1];
      return;
    }
    activeTokenId = tokenIds[index - 1];
  }

  function handleRightClick() {
    const index = tokenIds.indexOf(activeTokenId);
    if (index === tokenIds.length - 1) {
      activeTokenId = tokenIds[0];
      return;
    }
    activeTokenId = tokenIds[index + 1];
  }

  $: activeTokenId, (window.location.hash = `#minted-${tokenIds.indexOf(activeTokenId)}`);
</script>

<div class={wrapperClasses}>
  <IconButton on:click={handleLeftClick} class={leftIconButtonClasses} icon="AngleLeft" type="neutral" size="lg" />

  <div class={carouselWrapperClasses}>
    {#each tokenIds as tokenId, i}
      <div id={`minted-${i}`} class={carouselItemClasses}>
        <NftRenderer size="md" {tokenId} />
      </div>
    {/each}
  </div>

  <IconButton on:click={handleRightClick} class={rightIconButtonClasses} size="lg" icon="AngleRight" type="neutral" />
</div>

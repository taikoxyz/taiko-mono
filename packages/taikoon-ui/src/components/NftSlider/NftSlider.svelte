<script lang="ts">
  import { IconButton } from '$components/core/IconButton';
  import { NftRenderer } from '$components/NftRenderer';

  import {  leftIconButtonClasses, rightIconButtonClasses, wrapperClasses } from './classes';

  export let tokenIds: number[] = [];
</script>

<div class={wrapperClasses}>

  <IconButton class={leftIconButtonClasses}
  icon="AngleLeft" type="neutral" size="lg" />

  <NftRenderer class="z-0" size="md" tokenId={1} />

  <IconButton class={rightIconButtonClasses} size="lg" icon="AngleRight" type="neutral" />
</div>

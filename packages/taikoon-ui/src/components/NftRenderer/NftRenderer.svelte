<script lang="ts">
  export let tokenId: number = -1;

  import TaikoonBlack from '$assets/taikoon-black-frame.png';
  import TaikoonWhite from '$assets/taikoon-white-frame.png';
  import { DynamicImage } from '$components/DynamicImage';
  import IPFS from '$lib/ipfs';
  import { classNames } from '$lib/util/classNames';
  import { Theme, theme } from '$stores/theme';
  import { Spinner } from '$ui/Spinner';

  $: isDarkTheme = $theme === Theme.DARK;

  export let size: 'full' | 'sm' | 'md' | 'lg' | 'xl' = 'full';

  let tokenURI = '';

  async function getTokenUri(id: number) {
    if (tokenId <= 0 || Number.isNaN(id)) return '';
    const metadata = await IPFS.getMetadata(id);
    if (!metadata || !metadata.image) return '';
    tokenURI = metadata.image;
  }

  $: wrapperClasses = classNames(
    size === 'full' ? 'w-full' : null,
    size === 'sm' ? 'w-32 h-32 rounded-lg' : null,
    size === 'md' ? 'w-64 h-64 rounded-xl' : null,
    size === 'lg' ? 'w-80 h-80 rounded-2xl' : null,
    size === 'xl' ? 'w-96 h-96 rounded-3xl' : null,
    'overflow-hidden',
    'flex flex-col items-center justify-center',
    $$props.class,
  );

  const imageClasses = classNames(
    'object-cover',
    'object-center',

    'w-full h-full',
  );

  $: tokenId, getTokenUri(tokenId);
</script>

<div class={wrapperClasses}>
  {#if tokenId >= 0}
    {#if tokenURI}
      <DynamicImage class={imageClasses} src={tokenURI} />
    {:else}
      <Spinner />{/if}
  {:else}
    <img class={imageClasses} src={isDarkTheme ? TaikoonWhite : TaikoonBlack} alt="Taikoon" />
  {/if}
</div>

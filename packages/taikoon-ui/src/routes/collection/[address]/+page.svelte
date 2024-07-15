<script lang="ts">
  import { onMount } from 'svelte';

  import { Collection } from '$components/Collection';
  import { Spinner } from '$components/core/Spinner';
  import { Page } from '$components/Page';
  import Token from '$lib/token';
  import { shortenAddress } from '$lib/util/shortenAddress';
  import { account } from '$stores/account';
  import { Section } from '$ui/Section';

  export let data: any;

  $: tokenIds = [] as number[];
  $: isLoading = false;
  $: title = '';

  async function load() {
    isLoading = true;
    const { address } = data;
    const isSelfCollection = $account && $account.address?.toLowerCase() === address.toLowerCase();
    const shortenedAddress = await shortenAddress(address);
    const ownerTokenIds = await Token.tokenOfOwner(address.toLowerCase());
    title = isSelfCollection ? 'Your Collection' : `${shortenedAddress}'s Collection`;
    tokenIds = ownerTokenIds;
    isLoading = false;
  }

  onMount(async () => {
    await load();
  });

  $: $account, load();
</script>

<svelte:head>
  <title>Taikoons | Collection</title>
</svelte:head>

<Page class="z-0">
  <Section animated class="justify-center items-center">
    {#if isLoading}
      <Spinner size="lg" />
    {:else}
      <Collection bind:isLoading {tokenIds} {title} />
    {/if}
  </Section>
</Page>

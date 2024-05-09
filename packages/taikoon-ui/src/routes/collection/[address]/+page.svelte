<script lang="ts">
  import { onMount } from 'svelte';

  import { goto } from '$app/navigation';
  import { Collection } from '$components/Collection';
  import { Page } from '$components/Page';
  import Token from '$lib/token';
  import isCountdownActive from '$lib/util/isCountdownActive';
  import { shortenAddress } from '$lib/util/shortenAddress';
  import { Section } from '$ui/Section';

  export let data: any;

  $: tokenIds = [0];
  $: isLoading = false;
  $: title = 'The Collection';

  onMount(async () => {
    isLoading = true;
    const { address } = data;
    title = `${await shortenAddress(address)}'s Collection`;
    tokenIds = await Token.tokenOfOwner(address.toLowerCase());
    isLoading = false;
  });

  if (isCountdownActive()) {
    goto('/');
  }
</script>

<svelte:head>
  <title>Taikoons | Collection</title>
</svelte:head>

<Page class="z-0">
  <Section animated>
    <Collection bind:isLoading {tokenIds} {title} />
  </Section>
</Page>

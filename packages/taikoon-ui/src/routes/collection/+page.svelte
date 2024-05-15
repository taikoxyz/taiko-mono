<script lang="ts">
  import { onMount } from 'svelte';

  import { goto } from '$app/navigation';
  import { Collection } from '$components/Collection';
  import { Page } from '$components/Page';
  import Token from '$lib/token';
  import isCountdownActive from '$lib/util/isCountdownActive';
  import { Section } from '$ui/Section';

  $: tokenIds = [] as number[];
  $: isLoading = false;
  $: totalSupply = 0;

  onMount(async () => {
    isLoading = true;
    totalSupply = await Token.totalSupply();
    tokenIds = Array.from({ length: totalSupply }, (_, i) => i + 1);
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
  <Section animated width="xl">
    <Collection bind:isLoading {tokenIds} />
  </Section>
</Page>

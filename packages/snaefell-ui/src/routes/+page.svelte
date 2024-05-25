<script lang="ts">
  import { ResponsiveController } from '$components/core/ResponsiveController';
  import { Mint } from '$components/Mint';
  import { CountdownSection, FooterSection, HeadingSection } from '$components/sections';
  import isCountdownActive from '$lib/util/isCountdownActive';
  import { Button } from '$ui/Button';
  import { Section, SectionContainer } from '$ui/Section';
  let windowSize: 'sm' | 'md' | 'lg' = 'md';

  let scrollTarget: HTMLElement | undefined = undefined;

  function scrollToFaq() {
    if (!scrollTarget) return;
    scrollTarget.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }
</script>

<svelte:head>
  <title>Alpha NFT</title>
</svelte:head>

<SectionContainer>
  {#if isCountdownActive()}
    <CountdownSection />
  {:else}
    <HeadingSection>
      <div class="bottom-16 left-0 w-full flex justify-center absolute">
        <Button type="primary" size="xl" iconRight="ArrowDown" on:click={scrollToFaq} class="uppercase"
          >Mint Now</Button>
      </div>
    </HeadingSection>
  {/if}

  {#if !isCountdownActive()}
    <div bind:this={scrollTarget}>
      <Section width={windowSize === 'sm' ? 'full' : 'md'} class="items-center justify-center" height={'full'}>
        <Mint />
      </Section>
    </div>
  {/if}
  <FooterSection />
</SectionContainer>

<ResponsiveController bind:windowSize />

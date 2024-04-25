<script lang="ts">
  import {
    CollapsibleSection,
    CountdownSection,
    FooterSection,
    HeadingSection,
    InformationSection,
  } from '$components/sections';
  import FaqOptions from '$content/faq';
  import { Button } from '$ui/Button';
  import { SectionContainer } from '$ui/Section';

  $: currentPage = 'teaser';

  let scrollTarget: HTMLElement | undefined = undefined;

  function scrollToWtf() {
    if (!scrollTarget) return;
    scrollTarget.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }
</script>

<svelte:head>
  <title>Taikoons</title>
</svelte:head>

<SectionContainer>
  {#if currentPage === 'teaser'}
    <CountdownSection>
      <div class="bottom-16 left-0 w-full flex justify-center absolute">
        <Button type="ghost" size="lg" iconRight="ArrowDown" on:click={scrollToWtf} class="uppercase">wtf?</Button>
      </div>
    </CountdownSection>
  {:else}
    <HeadingSection>
      <div class="bottom-16 left-0 w-full flex justify-center absolute">
        <Button type="ghost" size="lg" iconRight="ArrowDown" on:click={scrollToWtf} class="uppercase">wtf?</Button>
      </div>
    </HeadingSection>
  {/if}
  <div bind:this={scrollTarget}>
    <InformationSection />
  </div>
  <CollapsibleSection options={FaqOptions} />

  <FooterSection />
</SectionContainer>

<Button
  type="primary"
  on:click={() => {
    currentPage = currentPage === 'teaser' ? 'landing' : 'teaser';
  }}
  class="fixed uppercase top-32 left-16 z-100">
  {currentPage}
</Button>

<script lang="ts">
  import { t } from 'svelte-i18n';

  import {
    CollapsibleSection,
    CountdownSection,
    FooterSection,
    HeadingSection,
    InformationSection,
  } from '$components/sections';
  import { Button } from '$ui/Button';
  import { SectionContainer } from '$ui/Section';

  $: currentPage = 'teaser';

  $: faqOptions = $t('content.sections.faq.entries');

  let scrollTarget: HTMLElement | undefined = undefined;

  function scrollToFaq() {
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
        <Button type="ghost" size="lg" iconRight="ArrowDown" on:click={scrollToFaq} class="uppercase"
          >{$t('buttons.learnMore')}</Button>
      </div>
    </CountdownSection>
  {:else}
    <HeadingSection>
      <div class="bottom-16 left-0 w-full flex justify-center absolute">
        <Button type="ghost" size="lg" iconRight="ArrowDown" on:click={scrollToFaq} class="uppercase"
          >{$t('buttons.learnMore')}</Button>
      </div>
    </HeadingSection>
  {/if}
  <InformationSection />
  <div bind:this={scrollTarget}>
    <CollapsibleSection options={faqOptions} />
  </div>

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

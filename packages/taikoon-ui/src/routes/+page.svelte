<script lang="ts">
  import { t } from 'svelte-i18n';

  import {
    CountdownSection,
    FaqSection,
    FooterSection,
    HeadingSection,
    InformationSection,
    PreviewSection,
  } from '$components/sections';
  import isCountdownActive from '$lib/util/isCountdownActive';
  import { Button } from '$ui/Button';
  import { SectionContainer } from '$ui/Section';

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
  {#if isCountdownActive()}
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
  <PreviewSection />
  <div bind:this={scrollTarget}>
    <FaqSection />
  </div>

  <FooterSection />
</SectionContainer>

<script lang="ts">
  import { goto } from '$app/navigation';
  import { ResponsiveController } from '$components/core/ResponsiveController';
  import { Mint } from '$components/Mint';
  import { MintAgreementModal } from '$components/modals';
  import { Page } from '$components/Page';
  import { FaqSection, FooterSection } from '$components/sections';
  import isCountdownActive from '$lib/util/isCountdownActive';
  import { Section, SectionContainer } from '$ui/Section';

  let windowSize: 'sm' | 'md' | 'lg' = 'md';

  if (isCountdownActive()) {
    goto('/');
  }
</script>

<svelte:head>
  <title>Taikoons | Mint</title>
</svelte:head>

<Page>
  <SectionContainer>
    <Section
      animated
      width={windowSize === 'sm' ? 'full' : 'md'}
      class="items-center justify-center"
      height={windowSize === 'sm' ? 'fit' : 'full'}>
      <Mint />
    </Section>
    <FaqSection />

    <FooterSection />
  </SectionContainer>
</Page>

<MintAgreementModal />

<ResponsiveController bind:windowSize />

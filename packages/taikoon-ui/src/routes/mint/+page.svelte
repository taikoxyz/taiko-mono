<script lang="ts">
  import { ResponsiveController } from '@taiko/ui-lib';

  import { Mint } from '$components/Mint';
  import { MintDisclaimerModal } from '$components/modals';
  import { Page } from '$components/Page';
  import { FaqSection, FooterSection } from '$components/sections';
  import { Section, SectionContainer } from '$ui/Section';

  let windowSize: 'sm' | 'md' | 'lg' = 'md';
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

<MintDisclaimerModal />

<ResponsiveController bind:windowSize />

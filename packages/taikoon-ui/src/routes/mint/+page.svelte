<script lang="ts">
  import { t } from 'svelte-i18n';

  import { ResponsiveController } from '$components/core/ResponsiveController';
  import { Mint } from '$components/Mint';
  import { MintAgreementModal } from '$components/modals';
  import { Page } from '$components/Page';
  import { CollapsibleSection, FooterSection } from '$components/sections';
  import { Section, SectionContainer } from '$ui/Section';

  let windowSize: 'sm' | 'md' | 'lg' = 'md';

  $: faqOptions = $t('content.sections.faq.entries');
</script>

<svelte:head>
  <title>Taikoons | Mint</title>
</svelte:head>

<Page>
  <SectionContainer>
    <Section
      width={windowSize === 'sm' ? 'full' : 'md'}
      class="items-center justify-center"
      height={windowSize === 'sm' ? 'fit' : 'full'}>
      <Mint />
    </Section>
    <CollapsibleSection options={faqOptions} />

    <FooterSection />
  </SectionContainer>
</Page>

<MintAgreementModal />

<ResponsiveController bind:windowSize />

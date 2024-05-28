<script lang="ts">
  import { ResponsiveController } from '@taiko/ui-lib';

  import { NftRenderer } from '$components/NftRenderer';
  import { FooterSection } from '$components/sections';
  import { Section, SectionContainer } from '$ui/Section';
  let windowSize: 'sm' | 'md' | 'lg' = 'md';
</script>

<svelte:head>
  <title>Snaefell NFT</title>
</svelte:head>

<SectionContainer>
  <Section
    width={windowSize === 'sm' ? 'full' : 'md'}
    background="general"
    class="items-center justify-center"
    height={'full'}>
    <div class="w-[50vw] max-w-[400px]">
      <NftRenderer />
    </div>
  </Section>

  <FooterSection />
</SectionContainer>

<ResponsiveController bind:windowSize />

<script lang="ts">
  import { ResponsiveController } from '$components/core/ResponsiveController';
  import { Mint } from '$components/Mint';
  import { FooterSection } from '$components/sections';
  import { Section, SectionContainer } from '$ui/Section';
  let windowSize: 'sm' | 'md' | 'lg' = 'md';
</script>

<svelte:head>
  <title>Snaefell NFT</title>
</svelte:head>

<SectionContainer>
  <Section width={windowSize === 'sm' ? 'full' : 'md'} animated class="items-center justify-center" height={'full'}>
    <Mint />
  </Section>

  <FooterSection />
</SectionContainer>

<ResponsiveController bind:windowSize />

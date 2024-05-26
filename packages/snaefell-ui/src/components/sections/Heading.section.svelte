<script lang="ts">
  import Logo from '$assets/alpha-testnet-contributor.png';
  import { ResponsiveController } from '$components/core/ResponsiveController';
  import { classNames } from '$lib/util/classNames';
  import { Section } from '$ui/Section';

  let windowSize: 'sm' | 'md' | 'lg' = 'md';

  const sectionClasses = 'items-center justify-center';
  const imageClasses = classNames('w-1/2', 'h-auto', 'mb-20');
</script>

<Section animated={true} width={windowSize === 'sm' ? 'lg' : 'md'} class={sectionClasses}>
  <img src={Logo} alt="Alpha NFT Logo" class={imageClasses} />

  <slot />
</Section>

<ResponsiveController bind:windowSize />

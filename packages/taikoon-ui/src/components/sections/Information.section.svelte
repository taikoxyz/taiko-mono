<script lang="ts">
  import { classNames } from '$lib/util/classNames';
  import { Section } from '$ui/Section';
</script>

<Section height="min">
  <p
    class={classNames(
      'w-full',
      'text-left',
      'text-primary',
      'mb-4',
      'uppercase',
      'text-base',
      'font-bold',
      'font-sans',
      'leading-relaxed',
    )}>
    The Collection
  </p>

  <div class={classNames('md:font-normal', 'font-medium', 'md:text-6xl', 'font-clash-grotesk', 'text-4xl')}>
    The 888 Taikoons are the genesis NFT collection for the Taiko Layer 2 ecosystem, designed to foster community growth
    and establish unique on-chain identities.
  </div>
  <slot />
</Section>

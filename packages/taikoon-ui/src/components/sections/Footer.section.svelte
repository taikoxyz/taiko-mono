<script lang="ts">
  import { Footer } from '@taiko/ui-lib';
  import { ResponsiveController } from '@taiko/ui-lib';

  import { classNames } from '$lib/util/classNames';
  import { Section } from '$ui/Section';

  let windowSize: 'sm' | 'md' | 'lg' = 'md';

  const sectionClasses = classNames('justify-end align-end', 'mb-5');
</script>

<Section height={'fit'} background="footer" class={sectionClasses} width="xl">
  <Footer />
</Section>

<ResponsiveController bind:windowSize />

<script lang="ts">
  import { onMount } from 'svelte';

  import { AnimatedArrow } from '$components/AnimatedArrow';
  import { Collection } from '$components/Collection';
  import { Page } from '$components/Page';
  import { classNames } from '$lib/util/classNames';
  import { Section } from '$ui/Section';

  $: tokenIds = [] as number[];

  onMount(async () => {
    tokenIds = Array.from({ length: 50 }, (_, i) => i + 1);
  });

  const titleClasses = classNames(
    'w-full',
    'text-left',
    'text-primary',
    'mb-4',
    'uppercase',
    'tracking-normal',
    'text-[16px]/[24px]',
    'font-bold',
    'font-sans',
    'leading-relaxed',
  );

  const titleRowClasses = classNames('flex', 'flex-row', 'justify-between', 'items-center', 'mb-12');

  const bottomRowClasses = classNames(
    'h-[10vh]',
    'py-6',
    'w-full',
    'flex',
    'flex-row',
    'justify-center',
    'items-center',
  );

  const collectionTitleClasses = classNames('text-[57px]/[64px]', 'font-clash-grotesk', 'font-medium');

  const exploreMoreButtonClasses = classNames(
    'bg-[#E81899]',
    'font-sans',
    'w-max',
    'text-[#F3F3F3]',
    'px-3',
    'py-2',
    'rounded-full',
    'flex',
    'flex-row',
    'items-center',
    'justify-center',
    'text-base',
    'font-bold',
    'gap-2.5',
    'hover:bg-[#C8047D]',
  );

  const viewMoreButtonClasses = classNames(
    'border',
    'border-primary',
    'font-sans',
    'w-max',
    'text-[#F3F3F3]',
    'px-3',
    'py-2',
    'rounded-full',
    'flex',
    'flex-row',
    'items-center',
    'justify-center',
    'text-base',
    'font-bold',
    'gap-2.5',
    'hover:bg-[#C8047D]',
  );

  $: isHovered = false;

  const topRowClasses = classNames('absolute', 'z-50', 'top-32', 'left-0', 'px-16', 'w-full');

  const collectionWrapperClasses = classNames('w-full', 'h-[90vh]');
</script>

<Page class="z-0">
  <Section animated class="relative" width="xl">
    <div class={collectionWrapperClasses}>
      <Collection disableClick={true} {tokenIds} title="The 888 Collection" />
    </div>
    <div class={topRowClasses}>
      <p class={titleClasses}>Explore Taikoons</p>

      <div class={titleRowClasses}>
        <div class={collectionTitleClasses}></div>

        <a
          href="/collection"
          on:mouseenter={() => (isHovered = true)}
          on:mouseleave={() => (isHovered = false)}
          class={exploreMoreButtonClasses}>
          Explore More
          <AnimatedArrow {isHovered} />
        </a>
      </div>
    </div>

    <div class={bottomRowClasses}>
      <a
        href="/collection"
        on:mouseenter={() => (isHovered = true)}
        on:mouseleave={() => (isHovered = false)}
        class={viewMoreButtonClasses}>
        View More
        <AnimatedArrow {isHovered} />
      </a>
    </div>
  </Section>
</Page>

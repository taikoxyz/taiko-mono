<script lang="ts">
  import { t } from 'svelte-i18n';

  import { classNames } from '$lib/util/classNames';
  import { Section } from '$ui/Section';
  export let options: {
    visible?: boolean;
    title: string;
    text: string;
  }[] = [];

  $: activeEntryId = -1;

  const titleClasses = classNames('text-5xl', 'font-semibold');

  const wrapperClasses = classNames(
    'w-full h-full',
    'flex flex-col',
    'items-start',
    'justify-center',
    'gap-10',
    'md:text-[1.75rem]',
    'text-xl',
  );

  const collapseWrapperClasses = classNames(
    'w-full',
    'flex flex-col',
    'items-center',
    'justify-center',
    'overflow-hidden',
    'gap-4',
  );

  const collapseItemClasses = classNames(
    'w-full',
    'rounded-[20px]',
    'bg-neutral-background',
    'py-4',
    'h-min',
    'px-6',
    'border-opacity-50',
    'hover:text-primary',
    'collapse',
    'collapse-arrow',
  );
  const collapseTitleClasses = classNames(
    'flex',
    'flex-row',
    'w-full',
    'justify-between',
    'items-center',
    'text-[26px]/[32px]',
    'font-medium',
    'font-clash-grotesk',
    'collapse-title',
    'tracking-normal',
  );
  const collapseContentClasses = classNames(
    'text-[16px]/[24px]',
    'text-content-secondary',
    'font-sans',
    'collapse-content',
    'tracking-normal',
  );
  /* eslint-disable */
</script>

<Section height="fit">
  <div class={wrapperClasses}>
    <div class={titleClasses}>
      {$t('content.sections.faq.title')}
    </div>

    <div class={collapseWrapperClasses}>
      {#each options as option, i}
        <!-- svelte-ignore a11y-click-events-have-key-events -->
        <!-- svelte-ignore a11y-no-static-element-interactions -->
        <div on:click={() => (activeEntryId = activeEntryId === i ? -1 : i)} class={collapseItemClasses}>
          <input class="hidden" type="radio" name="faq-radio-group" checked={i === activeEntryId} />
          <div class={collapseTitleClasses}>
            {option.title}
          </div>
          <div class={classNames(collapseContentClasses, i === activeEntryId ? 'mt-4' : null)}>
            {@html option.text}
          </div>
        </div>
      {/each}
    </div>
  </div>
</Section>

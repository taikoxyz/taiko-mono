<script lang="ts">
  import { Icons } from '$ui/Icons';

  import { classNames } from '../../../lib/util/classNames';
  import type { IconType } from '../../../types';
  import { Spinner } from '../Spinner';

  type ButtonType =
    | 'neutral'
    | 'primary'
    | 'secondary'
    | 'accent'
    | 'info'
    | 'success'
    | 'warning'
    | 'error'
    | 'ghost'
    | 'link'
    | 'negative'
    | 'mobile';
  type ButtonShape = 'circle' | 'square';

  export let type: ButtonType = 'neutral';
  export let shape: ButtonShape = 'square';
  export let loading = false;
  export let outline = false;
  export let block = false;
  export let wide = false;
  export let label = '';
  export let iconLeft: IconType | null = null;
  export let iconRight: IconType | null = null;
  export let size: 'sm' | 'md' | 'lg' | 'xl' = 'md';
  export let hasBorder = false;
  export let href: string | undefined = undefined;

  let borderClasses: string = '';

  if (hasBorder) {
    borderClasses = 'border-1 border-primary-border';
  } else {
    borderClasses = 'border-0';
  }

  // Remember, with Tailwind's classes you cannot use string interpolation: `btn-${type}`.
  // The whole class name must appear in the code in order for Tailwind compiler to know
  // it must be included during build-time.
  // https://tailwindcss.com/docs/content-configuration#dynamic-class-names
  const typeMap: Record<ButtonType, string> = {
    neutral: 'btn-neutral',
    primary: 'btn-primary',
    secondary: 'btn-secondary',
    accent: 'btn-accent',
    info: 'btn-info',
    success: 'btn-success',
    warning: 'btn-warning',
    error: 'btn-error',
    ghost: 'btn-ghost',
    link: 'btn-link',
    negative:
      'border border-primary bg-transparent font-bold font-sans hover:bg-content-link-primary hover:border-transparent',
    mobile: classNames('text-xl', 'w-full', 'bg-neutral-background', 'py-4', 'justify-start'),
  };

  const shapeMap: Record<ButtonShape, string> = {
    circle: 'btn-circle',
    square: 'btn-square',
  };

  $: classes = classNames(
    'flex flex-row',
    'btn h-auto min-h-fit rounded-full',

    'font-sans',
    type === 'primary' ? 'font-bold' : 'font-regular',

    type === 'primary' ? 'body-bold text-[#F3F3F3]' : 'body-regular',

    type !== 'mobile' ? 'items-center justify-center' : null,
    type ? typeMap[type] : null,
    shape ? shapeMap[shape] : null,

    type === 'neutral' ? 'bg-dialog-background w-[200px]' : null,

    outline ? 'btn-outline' : null,
    block ? 'btn-block' : null,
    wide ? 'btn-wide' : null,

    'min-w-max',

    // For loading state we want to see well the content,
    // since we're showing some important information.
    loading ? 'btn-disabled !text-primary-content' : null,

    $$restProps.disabled ? borderClasses : '',

    type === 'link'
      ? 'text-text-dark p0 font-bold'
      : size === 'sm'
        ? 'py-2 px-5'
        : size === 'md'
          ? 'py-3 px-7'
          : size === 'lg'
            ? 'py-5 px-9 text-xl font-bold'
            : size === 'xl'
              ? 'py-2 w-max pl-6 pr-2 text-xl font-bold'
              : null,

    $$props.class,
  );

  // Make sure to disable the button if we're in loading state
  $: if (loading) {
    $$restProps.disabled = true;
  }

  $: iconSize = size === 'sm' ? 16 : size === 'md' ? 16 : size === 'lg' ? 28 : 42;

  const iconClasses = classNames('mx-1', size === 'lg' ? 'font-bold' : null);
</script>

{#if href}
  <a {...$$restProps} {href} on:click class={classes}>
    {#if loading}
      <Spinner class={iconClasses} size="sm" />
    {:else if iconLeft}
      <svelte:component this={Icons[iconLeft]} size={iconSize.toString()} class={iconClasses} />
    {/if}
    {#if label}
      {label}
    {:else}
      <slot />
    {/if}
    {#if iconRight}
      <svelte:component this={Icons[iconRight]} size={iconSize.toString()} class={iconClasses} />
    {/if}
  </a>
{:else}
  <button {...$$restProps} class={classes} on:click>
    {#if loading}
      <Spinner class={iconClasses} size="sm" />
    {:else if iconLeft}
      <svelte:component this={Icons[iconLeft]} size={iconSize.toString()} class={iconClasses} />
    {/if}
    {#if label}
      {label}
    {:else}
      <slot />
    {/if}
    {#if iconRight}
      <svelte:component this={Icons[iconRight]} size={iconSize.toString()} class={iconClasses} />
    {/if}
  </button>
{/if}

<script lang="ts">
  import { Spinner } from '$components/Spinner';
  import { classNames } from '$libs/util/classNames';

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
    | 'link';
  type ButtonShape = 'circle' | 'square';

  export let type: Maybe<ButtonType> = null;
  export let shape: Maybe<ButtonShape> = null;
  export let loading = false;
  export let outline = false;
  export let block = false;
  export let wide = false;

  export let hasBorder = false;

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
  };

  const shapeMap: Record<ButtonShape, string> = {
    circle: 'btn-circle',
    square: 'btn-square',
  };

  $: classes = classNames(
    'btn h-auto min-h-fit ',

    type === 'primary' ? 'body-bold' : 'body-regular',

    type ? typeMap[type] : null,
    shape ? shapeMap[shape] : null,

    outline ? 'btn-outline' : null,
    block ? 'btn-block' : null,
    wide ? 'btn-wide' : null,

    // For loading state we want to see well the content,
    // since we're showing some important information.
    loading ? 'btn-disabled !text-primary-content' : null,

    $$restProps.disabled ? borderClasses : '',

    $$props.class,
  );

  // Make sure to disable the button if we're in loading state
  $: if (loading) {
    $$restProps.disabled = true;
  }
</script>

<button {...$$restProps} class={classes} on:click>
  {#if loading}
    <Spinner />
  {/if}

  <slot />
</button>

<script lang="ts">
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
  export let outline = false;
  export let block = false;
  export let wide = false;

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

  const classes = classNames(
    'btn h-auto min-h-fit border-0',
    type ? typeMap[type] : null,
    shape ? shapeMap[shape] : null,
    outline ? 'btn-outline' : null,
    block ? 'btn-block' : null,
    wide ? 'btn-wide' : null,
    $$props.class,
  );
</script>

<button {...$$restProps} class={classes} on:click>
  <slot />
</button>

<script lang="ts">
  import { classNames } from '$libs/util/classNames';

  type ButtonType = 'neutral' | 'primary' | 'secondary' | 'accent' | 'info' | 'success' | 'warning' | 'error' | 'ghost';
  type ButtonSize = 'lg' | 'md' | 'sm' | 'xs';
  type ButtonShape = 'circle' | 'square';

  export let type: Maybe<ButtonType> = null;
  export let size: Maybe<ButtonSize> = null;
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
  };

  const sizeMap: Record<ButtonSize, string> = {
    lg: 'btn-lg',
    md: 'btn-md',
    sm: 'btn-sm',
    xs: 'btn-xs',
  };

  const shapeMap: Record<ButtonShape, string> = {
    circle: 'btn-circle',
    square: 'btn-square',
  };

  const classes = classNames(
    'btn btn-sm md:btn-md',
    type ? typeMap[type] : null,
    size ? sizeMap[size] : null,
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

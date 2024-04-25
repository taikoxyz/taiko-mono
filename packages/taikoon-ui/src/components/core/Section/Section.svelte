<script lang="ts">
  import { AnimatedBackground } from '$ui/AnimatedBackground';

  import { classNames } from '../../../lib/util/classNames';

  export let height: 'full' | 'min' | 'fit' = 'full';
  export let width: 'sm' | 'md' | 'lg' | 'xl' | 'full' = 'lg';
  export let background: 'general' | 'footer' | 'none' = 'none';

  let classes: string = '';
  export { classes as class };
  let elementId: string = '';
  export { elementId as id };
  export let animated: boolean = false;

  $: wrapperClasses = classNames(
    'w-full',
    'overflow-hidden',
    height === 'full' ? 'h-screen' : null,
    height === 'min' ? 'h-[50vh] pt-32' : null,
    height === 'fit' ? 'h-auto' : null,
    'relative',
    'flex flex-col',
    'items-center',
    'justify-center',

    background !== 'none' ? 'bg-cover bg-center' : null,
    background === 'general' ? 'bg-general' : null,
    background === 'footer' ? 'bg-footer' : null,
  );

  $: sectionClasses = classNames(
    'w-full',
    'h-full',
    'z-10',
    width === 'sm' ? 'md:px-64 px-32' : null,
    width === 'md' ? 'md:px-32 px-16' : null,
    width === 'lg' ? 'md:px-20 px-10' : null,
    width === 'xl' ? 'md:px-8 px-4' : null,
    width === 'full' ? 'px-0' : null,
    'flex flex-col',
    classes === '' ? 'items-center justify-center' : classes,
  );
</script>

<section id={elementId} class={wrapperClasses}>
  <AnimatedBackground {animated} />

  <div class={sectionClasses}>
    <slot />
  </div>
</section>

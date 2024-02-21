<script lang="ts">
  import Spinner from '$components/Spinner/Spinner.svelte';
  import { classNames } from '$libs/util/classNames';

  export let text = 'Loading';
  export let textClass = '';
  export let spinnerClass = '';

  let classes = classNames(
    'gap-2 z-10',
    'f-center',
    'absolute',
    'top-0 bottom-0',
    'left-0 right-0',
    'overflow-hidden',
    'overlay-dialog',
    'text-white',
    $$props.class,
  );
  let textClasses = classNames('body-regular', textClass);
</script>

<div class={classes}>
  <Spinner class={spinnerClass} />
  <span class={textClasses}>{text}</span>
</div>

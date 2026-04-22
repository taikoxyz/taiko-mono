<script lang="ts">
  import TestTaikoon from '../../assets/test-taikoon.png';
  export let src: string | undefined = '';
  import { classNames } from '$lib/util/classNames';

  const imgClasses = classNames('w-full h-full', 'z-10', 'rendering-pixelated', $$props.class);
</script>

<img src={src ? src : TestTaikoon} alt="taikoon" class={imgClasses} />

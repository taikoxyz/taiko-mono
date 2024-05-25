<script lang="ts">
  import Logo from '$assets/alpha-testnet-contributor.png';
  import { classNames } from '$lib/util/classNames';

  export let size: 'full' | 'sm' | 'md' | 'lg' | 'xl' = 'full';

  $: wrapperClasses = classNames(
    size === 'full' ? 'w-full' : null,
    size === 'sm' ? 'w-32 h-32 rounded-lg' : null,
    size === 'md' ? 'w-64 h-64 rounded-xl' : null,
    size === 'lg' ? 'w-80 h-80 rounded-2xl' : null,
    size === 'xl' ? 'w-96 h-96 rounded-3xl' : null,
    'overflow-hidden',
    'flex flex-col items-center justify-center',
    $$props.class,
  );

  const imageClasses = classNames(
    'object-cover',
    'object-center',

    'w-full h-full',
  );
</script>

<div class={wrapperClasses}>
  <img class={imageClasses} src={Logo} alt="Taikoon" />
</div>

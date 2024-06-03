<script lang="ts">
  import Logo from '$assets/alpha-testnet-contributor.png';
  import { classNames } from '$lib/util/classNames';

  export let size: 'full' | 'sm' | 'md' | 'lg' | 'xl' = 'full';

  $: wrapperClasses = classNames(
    size === 'full' ? 'w-full' : null,
    size === 'sm' ? 'w-32 h-32' : null,
    size === 'md' ? 'w-64 h-64' : null,
    size === 'lg' ? 'w-80 h-80' : null,
    size === 'xl' ? 'w-96 h-96' : null,
    'overflow-hidden',
    'p-[36.5px]',
    'flex flex-col items-center justify-center',
    $$props.class,
  );

  const imageClasses = classNames('object-cover', 'object-center', 'rounded-full', 'w-full h-full');
</script>

<div class={wrapperClasses}>
  <img class={imageClasses} src={Logo} alt="Taikoon" />
</div>

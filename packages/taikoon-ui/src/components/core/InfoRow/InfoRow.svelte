<script lang="ts">
  import { classNames } from '../../../lib/util/classNames';
  import { Spinner } from '../Spinner';
  import { Link, P } from '../Text';

  export let label = 'label';
  export let value = 'value';
  export let href = '#';
  export let loading = false;

  const wrapperClasses = classNames('flex', 'flex-row', 'items-center', 'justify-between', 'w-full', $$props.class);

  const textClasses = classNames('font-bold');
  const linkClasses = classNames('font-bold', 'no-underline');
</script>

<div class={wrapperClasses}>
  <P class={textClasses}>{label}</P>
  <Link {href} class={linkClasses}>
    {#if loading}
      <Spinner size="xs" />
    {:else}
      {value}
    {/if}
  </Link>
</div>

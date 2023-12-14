<script lang="ts">
  import { Spinner } from '$components/Spinner';
  import { classNames } from '$libs/util/classNames';

  import { ButtonState } from './states';
  import type { ActionButtonType } from './types';

  export let loading = false;

  export let priority: ActionButtonType;
  export let state: ButtonState = ButtonState.DEFAULT;

  $: if (loading) {
    state = ButtonState.LOADING;
  } else {
    state = ButtonState.DEFAULT;
  }

  $: commonClasses = classNames('btn h-[56px] px-[28px] py-[14px] rounded-full flex-1 w-full', $$props.class);

  $: primaryClasses = classNames('btn-primary text-white border-none');

  $: secondaryClasses = classNames(
    'btn-secondary bg-transparent border-primary-brand dark:text-white light:text-black hover:bg-primary-interactive-hover',
  );

  $: priorityToClassMap = {
    primary: primaryClasses,
    secondary: secondaryClasses,
  };

  $: classes = classNames(commonClasses, priorityToClassMap[priority]);
</script>

<button {...$$restProps} class={classes} on:click>
  {#if loading}
    <Spinner />
  {/if}

  <slot />
</button>

<script lang="ts">
  import { classNames } from '$libs/util/classNames';
  export let activeStep: number = 0;

  const styles = `
    w-full 
    md:card 
    md:rounded-[20px] 
    md:border 
    md:border-divider-border
    dark:md:glassy-gradient-card
    dark:md:glass-background-gradient`;

  $: classes = classNames(styles, $$props.class);
</script>

<div class={classes}>
  <div class="card-body body-regular gap-0 p-0">
    <ul class="steps my-[30px]">
      <slot {activeStep} />
    </ul>
  </div>
</div>

<script lang="ts">
  import StepBack from '$components/Stepper/StepBack.svelte';
  import { classNames } from '$libs/util/classNames';
  export let activeStep: number = 0;

  const styles = ``;

  $: classes = classNames(styles, $$props.class);
</script>

<div class={classes}>
  <div class="card-body body-regular gap-0 p-0">
    <ul class="steps md:mb-[30px] mt-[30px]">
      <slot {activeStep} />
    </ul>
  </div>
</div>

<StepBack on:click />

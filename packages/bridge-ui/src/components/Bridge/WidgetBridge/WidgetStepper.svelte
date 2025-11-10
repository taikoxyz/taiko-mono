<script lang="ts">
  export let activeStep: number = 0;

  const styles = `
    w-full
  `;
</script>

<div class={styles}>
  <div class="card-body body-regular gap-0 p-0">
    <ul class="steps mt-[30px]">
      <slot {activeStep} />
    </ul>
  </div>
</div>

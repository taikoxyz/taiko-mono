<script lang="ts">
  export let isActive = false;
  export let stepIndex: number;
  export let currentStepIndex: number;
</script>

<li
  data-content=""
  class="step
  {isActive ? 'step-primary' : ''} 
  {stepIndex < currentStepIndex && !isActive ? 'step-previous' : ''}">
  <slot />
</li>

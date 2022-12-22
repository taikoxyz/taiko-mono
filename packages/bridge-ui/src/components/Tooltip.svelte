<script lang="ts">
  import { QuestionMarkCircle } from "svelte-heros-v2";

  export let isOpen: boolean = false;
</script>

<QuestionMarkCircle
  on:click={() => (isOpen = true)}
  size="18"
  variation="outline"
/>

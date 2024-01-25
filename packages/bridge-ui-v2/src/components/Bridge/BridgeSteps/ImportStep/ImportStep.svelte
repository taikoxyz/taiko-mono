<script lang="ts">
  import { importDone } from '$components/Bridge/state';

  import TokenInput from './TokenInput/TokenInput.svelte';

  let validInput = false;

  $: $importDone = validInput;
</script>

<TokenInput bind:validInput />

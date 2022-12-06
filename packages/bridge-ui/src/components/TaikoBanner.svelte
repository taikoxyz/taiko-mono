<script>
  import { _ } from "svelte-i18n";
  import SelectChain from "./form/SelectChain.svelte";
</script>

<div class="taiko-banner bg-cover bg-center bg-no-repeat w-full h-36 rounded-lg py-4 flex flex-col items-center justify-center">
  <h1 class="text-2xl font-bold">
    {$_("home.title")}
  </h1>
  <SelectChain />
</div>
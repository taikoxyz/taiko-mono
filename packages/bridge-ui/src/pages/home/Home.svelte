<script lang="ts">
  import SelectToken from "../../components/buttons/SelectToken.svelte";
  import { _ } from "svelte-i18n";
  import BridgeForm from "../../components/form/BridgeForm.svelte";
</script>

<div class="hero bg-base-100 mt-12">
  <div class="hero-content text-center">
    <div class="max-w-lg w-[460px]">
      <h1 class="text-2xl font-bold">
        {$_("home.title")}
      </h1>
      <div class="mt-8 flex items-center justify-center">
        <span class="font-bold mr-2">{$_("home.selectToken")}</span>
        <SelectToken />
      </div>
      <BridgeForm />
    </div>
  </div>
</div>

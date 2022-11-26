<script lang="ts">
  import SelectToken from "../../components/buttons/SelectToken.svelte";
  import { _ } from "svelte-i18n";
  import BridgeForm from "../../components/form/BridgeForm.svelte";
</script>

<div class="hero min-h-screen bg-base-100">
  <div class="hero-content text-center">
    <div class="max-w-md">
      <h1 class="text-xl font-bold">
        {$_("home.title")}
      </h1>
      {$_("home.selectToken")}
      <SelectToken />
      <BridgeForm />
    </div>
  </div>
</div>

<script lang="ts">
  import { _ } from "svelte-i18n";

  import BridgeForm from "../../components/form/BridgeForm.svelte";
  import TaikoBanner from "../../components/TaikoBanner.svelte";
</script>

<div class="hero bg-base-100">
  <div class="hero-content text-center">
    <div class="">
      <TaikoBanner />
      <!-- <div class="mt-8 flex items-center justify-center px-2">
        <span class="font-bold mr-2">{$_("home.selectToken")}</span>
        <SelectToken />
      </div> -->
      <div class="px-4">
        <BridgeForm />
      </div>
    </div>
  </div>
</div>

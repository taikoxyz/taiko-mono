<script lang="ts">
  import { ethers } from "ethers";
  import { signer } from "../../store/signer";
  import { _ } from "svelte-i18n";
  import { toast } from "@zerodevx/svelte-toast";

  async function connect() {
    try {
      const provider = new ethers.providers.Web3Provider(window.ethereum);

      await provider.send("eth_requestAccounts", []);

      signer.set(provider.getSigner());
      toast.push("Connected");
    } catch (e) {
      console.log(e);
      toast.push("Error connecting to wallet");
    }
  }
</script>

<button class="btn btn-wide" on:click={async () => await connect()}
  >{$_("nav.connect")}</button
>

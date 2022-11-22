<script lang="ts">
  import { ethers } from "ethers";
  import { signer } from "../../store/signer";
  import { _ } from "svelte-i18n";

  async function connect() {
    const provider = new ethers.providers.Web3Provider(window.ethereum);

    await provider.send("eth_requestAccounts", []);

    signer.set(provider.getSigner());
  }
</script>

<button class="btn" on:click={async () => await connect()}
  >{$_("nav.connect")}</button
>

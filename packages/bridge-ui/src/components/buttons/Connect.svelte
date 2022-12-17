<script lang="ts">
  import { BigNumber, ethers } from "ethers";
  import { signer } from "../../store/signer";
  import { _ } from "svelte-i18n";
  import { CHAIN_MAINNET, CHAIN_TKO } from "../..//domain/chain";
  import { fromChain, toChain } from "../../store/chain";
  import { ethereum } from "../../store/ethereum";
  import { isSwitchEthereumChainModalOpen } from "../../store/modal";
  import { errorToast, successToast } from "../../utils/toast";
  import { transactioner, transactions } from "../../store/transactions";

  async function connect() {
    try {
      const getAccounts = async () => {
        ethereum.set(window.ethereum);
        const provider = new ethers.providers.Web3Provider(window.ethereum);
        await provider.send("eth_requestAccounts", []);

        const s = provider.getSigner();
        signer.set(s);
        transactions.set(
          await $transactioner.GetAllByAddress(await s.getAddress())
        );
      };

      const changeChain = async (chainId: number) => {
        if (chainId === CHAIN_TKO.id) {
          fromChain.set(CHAIN_TKO);
          toChain.set(CHAIN_MAINNET);
        } else if (chainId === CHAIN_MAINNET.id) {
          fromChain.set(CHAIN_MAINNET);
          toChain.set(CHAIN_TKO);
        } else {
          isSwitchEthereumChainModalOpen.set(true);
        }
      };

      await getAccounts();

      const { chainId } = await $signer.provider.getNetwork();

      await changeChain(chainId);

      window.ethereum.on("chainChanged", async (chainId) => {
        await changeChain(BigNumber.from(chainId).toNumber());
      });

      window.ethereum.on("accountsChanged", async (accounts) => {
        await getAccounts();
      });

      successToast("Connected");
    } catch (e) {
      console.log(e);
      errorToast("Error connecting to wallet");
    }
  }
</script>

<button class="btn btn-md md:btn-wide" on:click={async () => await connect()}
  >{$_("nav.connect")}</button
>

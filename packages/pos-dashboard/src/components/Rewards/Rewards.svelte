<script lang="ts">
  import { TAIKO_L1_ADDRESS, TTKO_ADDRESS } from '../../constants/envVars';
  import { BigNumber, ethers } from 'ethers';
  import { signer } from '../../store/signer';
  import { getTaikoL1Balance } from '../../utils/getTaikoL1Balance';
  import { withdrawTaikoToken } from '../../utils/withdrawTaikoToken';
  import { depositTaikoToken } from '../../utils/depositTaikoToken';
  import { successToast } from '../NotificationToast.svelte';
  import { pendingTransactions } from '../../store/transaction';
  import { getTTKOBalance } from '../../utils/getTTKOBalance';
  import { switchNetwork } from '../../utils/switchNetwork';
  import { mainnetChain } from '../../chain/chains';
  import { srcChain } from '../../store/chain';

  let balance: BigNumber = BigNumber.from(0);
  let ttkoBalanceInWei: BigNumber = BigNumber.from(0);

  let amount: string = '0';

  let errorMessage: string = '';

  function updateAmount(event: Event) {
    const target = event.target as HTMLInputElement;
    amount = target.value;

    if (ethers.utils.parseUnits(amount, 8).gt(balance)) {
      errorMessage = 'Insufficient balance';
      return;
    } else {
      errorMessage = '';
    }
  }

  async function fetchTaikoL1Balance(signer: ethers.Signer) {
    if (!signer) return;
    balance = await getTaikoL1Balance(
      signer.provider,
      TAIKO_L1_ADDRESS,
      await signer.getAddress(),
    );
  }

  async function withdraw() {
    if ($srcChain.id !== mainnetChain.id) {
      await switchNetwork(mainnetChain.id);
    }

    const tx = await withdrawTaikoToken(
      $signer,
      TAIKO_L1_ADDRESS,
      ethers.utils.parseUnits(amount, 8),
    );

    successToast('Transaction sent to withdraw.');

    await pendingTransactions.add(tx, $signer);

    amount = '';
  }

  async function fetchTTKOBalance(signer: ethers.Signer) {
    if (!signer) return;
    ttkoBalanceInWei = await getTTKOBalance(
      signer.provider,
      TTKO_ADDRESS,
      await signer.getAddress(),
    );
  }

  async function deposit() {
    if ($srcChain.id !== mainnetChain.id) {
      await switchNetwork(mainnetChain.id);
    }

    const tx = await depositTaikoToken(
      $signer,
      TAIKO_L1_ADDRESS,
      ethers.utils.parseUnits(amount, 8),
    );

    successToast('Transaction sent to deposit.');

    await pendingTransactions.add(tx, $signer);

    amount = '';
  }

  $: fetchTaikoL1Balance($signer).catch(console.error);
  $: fetchTTKOBalance($signer).catch(console.error);
</script>

<div class="my-4 md:px-4">
  {#if balance}
    TaikoL1 Contract Balance: {ethers.utils.formatUnits(balance, 8)} TTKOe
    <br />
    Wallet Balance: {ethers.utils.formatUnits(ttkoBalanceInWei, 8)} TTKOe

    <div class="mb-2">
      <span class="label-text text-left block">Amount: </span>
      <div
        class="flex relative rounded-md bg-dark-2 justify-between items-center pr-4">
        <input
          id="amount"
          name="amount"
          type="number"
          min="0"
          class="input input-primary bg-dark-2 input-md md:input-lg w-full focus:ring-0 border-dark-2"
          value={amount}
          on:input={updateAmount} />
      </div>
    </div>

    <button
      disabled={errorMessage != ''}
      class="btn btn-accent"
      on:click={withdraw}>Withdraw</button>

    <button
      disabled={ttkoBalanceInWei.lt(ethers.utils.parseUnits(amount, 8))}
      class="btn btn-accent"
      on:click={deposit}>Deposit</button>
  {:else}
    Connect Wallet
  {/if}
</div>

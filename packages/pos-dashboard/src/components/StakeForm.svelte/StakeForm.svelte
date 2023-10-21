<script lang="ts">
  import { BigNumber, ethers } from 'ethers';
  import { signer } from '../../store/signer';
  import { getTTKOBalance } from '../../utils/getTTKOBalance';
  import { PROVER_POOL_ADDRESS, TTKO_ADDRESS } from '../../constants/envVars';
  import { stake } from '../../utils/stake';
  import { successToast } from '../NotificationToast.svelte';
  import { pendingTransactions } from '../../store/transaction';
  import { getProverRequirements } from '../../utils/getProverRequirements';
  import { switchNetwork } from '../../utils/switchNetwork';
  import { mainnetChain } from '../../chain/chains';
  import { srcChain } from '../../store/chain';
  import { mainnet } from 'wagmi';
  let ttkoBalanceInWei: BigNumber = BigNumber.from(0);
  let amount: string = '0';
  let rewardPerGas: number = 0;
  let capacity: number = 0;

  let errorMessage: string = '';

  // set sane defaults
  let minStakePerCapacity: BigNumber = BigNumber.from(10000);
  let minCapacity: BigNumber = BigNumber.from(128);

  function updateAmount(event: Event) {
    const target = event.target as HTMLInputElement;
    amount = target.value;
  }

  async function fetchTTKOBalance(signer: ethers.Signer) {
    if (!signer) return;
    ttkoBalanceInWei = await getTTKOBalance(
      signer.provider,
      TTKO_ADDRESS,
      await signer.getAddress(),
    );

    const reqs = await getProverRequirements(
      signer.provider,
      PROVER_POOL_ADDRESS,
    );
    minCapacity = reqs.minCapacity;
    minStakePerCapacity = reqs.minStakePerCapacity;
    amount = ethers.utils.formatUnits(minStakePerCapacity.toString(), 8);
    capacity = reqs.minCapacity;
  }

  async function submitForm() {
    if ($srcChain.id !== mainnetChain.id) {
      await switchNetwork(mainnetChain.id);
    }
    const tx = await stake(
      $signer,
      PROVER_POOL_ADDRESS,
      ethers.utils.parseUnits(amount, 8).mul(capacity),
      BigNumber.from(rewardPerGas),
      BigNumber.from(capacity),
    );

    successToast('Transaction sent to stake.');

    await pendingTransactions.add(tx, $signer);

    amount = '';
    rewardPerGas = 0;
    capacity = 0;
  }

  function handleRequirements(
    capacity: number,
    amount: string,
    rewardPerGas: number,
  ) {
    if (BigNumber.from(minCapacity).gt(capacity)) {
      errorMessage = `Minimum capacity is ${minCapacity}`;
      return;
    }

    if (minStakePerCapacity.gt(ethers.utils.parseUnits(amount, 8))) {
      errorMessage = `Minimum amount per capacity is ${ethers.utils.formatUnits(
        minStakePerCapacity,
        8,
      )}`;
      return;
    }

    if (rewardPerGas <= 0) {
      errorMessage = `Reward per gas must be greater than 0`;
      return;
    }

    const reqTtko = BigNumber.from(capacity).mul(
      BigNumber.from(ethers.utils.parseUnits(amount, 8)),
    );
    if (ttkoBalanceInWei.lt(reqTtko)) {
      errorMessage = `Not enough TTKO balance, Required: ${ethers.utils.formatUnits(
        reqTtko,
        8,
      )}`;
      return;
    }
    errorMessage = '';
  }

  $: handleRequirements(capacity, amount, rewardPerGas);
  $: fetchTTKOBalance($signer).catch(console.error);
</script>

<div class="space-y-6 md:space-y-4">
  {#if $signer}
    <div class="form-control">
      <label class="label" for="description" />
      <span class="label-text"
        >Staking to be a prover on Eldfell L3 requires you to provide some
        paramaters: the capacity (how many blocks you can prove simultaneously
        within the proof window), the amount you want to stake per capacity, and
        the reward you want to receive per gas. These parameters will influence
        your position on the top provers. 32 provers can be assigned blocks. You
        can click the "Current Provers" tab to see the current top 32 provers,
        and what staking amount you will require to override the bottom existing
        prover and enter the top 32.
      </span>
    </div>
    <span class="label-text block mt-4"
      ><span class="font-bold">Your TTKOe Balance:</span>
      {ethers.utils.formatUnits(ttkoBalanceInWei, 8)}</span>
    <br />

    <span class="label-text block" style="margin-top: 0;"
      ><span class="font-bold">Min Stake per Capacity:</span>
      {ethers.utils.formatUnits(minStakePerCapacity, 8)} TTKOe</span>
    <br />

    <span class="label-text block" style="margin-top: 0;"
      ><span class="font-bold">Min Capacity:</span>
      {minCapacity.toString()}</span>
    <br />

    <div>
      <span class="label-text text-left block mb-2 font-bold"
        >Amount per Capacity:
      </span>
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

    <div>
      <span class="label-text text-left block mb-2 font-bold"
        >RewardPerGas (in wei):
      </span>
      <div
        class="flex relative rounded-md bg-dark-2 justify-between items-center pr-4">
        <input
          id="rewardPerGas"
          name="rewardPerGas"
          type="number"
          placeholder="1"
          min="0"
          class="input input-primary bg-dark-2 input-md md:input-lg w-full focus:ring-0 border-dark-2"
          bind:value={rewardPerGas} />
      </div>
    </div>

    <div>
      <span class="label-text text-left block mb-2 font-bold">Capacity: </span>
      <div
        class="flex relative rounded-md bg-dark-2 justify-between items-center pr-4">
        <input
          id="capacity"
          name="capacity"
          type="number"
          min="0"
          class="input input-primary bg-dark-2 input-md md:input-lg w-full focus:ring-0 border-dark-2"
          bind:value={capacity} />
      </div>
    </div>

    {#if errorMessage}
      <p style="color: #E81898">{errorMessage}</p>
    {/if}
    <button
      disabled={errorMessage != ''}
      class="btn btn-accent"
      on:click={submitForm}>Stake</button>
  {:else}
    Connect Wallet
  {/if}
</div>

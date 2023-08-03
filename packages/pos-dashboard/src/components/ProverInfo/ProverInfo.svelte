<script lang="ts">
  import { PROVER_POOL_ADDRESS } from '../../constants/envVars';
  import type { Prover } from '../../domain/prover';
  import { ethers } from 'ethers';
  import { getProverInfo } from '../../utils/getProverInfo';
  import type { Staker } from '../../domain/staker';
  import { signer } from '../../store/signer';
  let proverInfo: { prover: Prover; staker: Staker; address: string };

  async function fetchProverInfo(signer: ethers.Signer) {
    if (!signer) return;
    proverInfo = await getProverInfo(
      signer.provider,
      PROVER_POOL_ADDRESS,
      await signer.getAddress(),
    );
  }

  $: fetchProverInfo($signer).catch(console.error);
</script>

<div class="my-4 md:px-4">
  {#if proverInfo}
    <p>Address: {proverInfo.address}</p>
    <p>
      Amount Staked: {ethers.utils.formatUnits(
        proverInfo.prover.stakedAmount.toString(),
        8,
      )}
    </p>
    <p>Max Capacity: {proverInfo.staker.maxCapacity}</p>
    <p>Current Capacity: {proverInfo.prover.currentCapacity}</p>
    <p>Prover ID: {proverInfo.staker.proverId}</p>
    <p>
      Exit Amount: {ethers.utils.formatUnits(proverInfo.staker.exitAmount, 8)} TTKO
    </p>
    <p>Exit Requested At: {proverInfo.staker.exitRequestedAt}</p>
  {:else}
    Connect wallet to view your current prover information
  {/if}
</div>

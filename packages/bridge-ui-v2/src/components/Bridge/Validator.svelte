<script lang="ts">
  import { checkBalanceToBridge } from '$libs/bridge';
  import { InsufficientAllowanceError, InsufficientBalanceError } from '$libs/error';
  import { account } from '$stores/account';
  import { network } from '$stores/network';

  import {
    destNetwork,
    enteredAmount,
    insufficientAllowance,
    insufficientBalance,
    processingFee,
    recipientAddress,
    selectedToken,
    tokenBalance,
  } from './state';

  export async function validate() {
    $insufficientBalance = false;
    $insufficientAllowance = false;

    const to = $recipientAddress || $account?.address;

    // We need all these guys to validate
    if (
      !to ||
      !$selectedToken ||
      !$network ||
      !$destNetwork ||
      !$tokenBalance ||
      $enteredAmount === BigInt(0) // no need to check if the amount is 0
    )
      return;

    try {
      await checkBalanceToBridge({
        to,
        token: $selectedToken,
        amount: $enteredAmount,
        processingFee: $processingFee,
        balance: $tokenBalance.value,
        srcChainId: $network.id,
        destChainId: $destNetwork.id,
      });
    } catch (err) {
      console.error(err);

      switch (true) {
        case err instanceof InsufficientBalanceError:
          $insufficientBalance = true;
          break;
        case err instanceof InsufficientAllowanceError:
          $insufficientAllowance = true;
          break;
      }
    }
  }
</script>

<script lang="ts">
  import { onDestroy, tick } from 'svelte';
  import { t } from 'svelte-i18n';
  import type { Chain } from 'viem';

  import { BridgingStatus, ImportMethod } from '$components/Bridge/types';
  import { Card } from '$components/Card';
  import { OnAccount } from '$components/OnAccount';
  import { OnNetwork } from '$components/OnNetwork';
  import { Step, Stepper } from '$components/Stepper';
  import { hasBridge } from '$libs/bridge/bridges';
  import { ProcessingFeeMethod } from '$libs/fee';
  import { ETHToken } from '$libs/token';
  import { isBridgePaused } from '$libs/util/checkForPausedContracts';
  import { type Account, account } from '$stores/account';

  import { ImportStep, ReviewStep, StepNavigation } from './NFTBridgeComponents';
  import { foundNFTs, selectedImportMethod } from './NFTBridgeComponents/ImportStep/state';
  import { ConfirmationStep, RecipientStep } from './SharedBridgeComponents';
  import {
    activeBridge,
    destNetwork as destinationChain,
    destOwnerAddress,
    gasLimitZero,
    importDone,
    processingFeeMethod,
    recipientAddress,
    selectedNFTs,
    selectedToken,
  } from './state';
  import { BridgeSteps } from './types';

  let recipientStepComponent!: RecipientStep;
  let bridgingStatus: BridgingStatus;

  let hasEnoughEth: boolean = false;
  let activeStep: BridgeSteps = BridgeSteps.IMPORT;

  let nftStepTitle: string;
  let nftStepDescription: string;

  // ImportStep owns the manual-import inputs; they live two levels down, so the reset and
  // revalidate calls below go through it. The AddressInput/IdInput references that used to
  // stand here were never bound to anything, which made every call on them a silent no-op.
  let importStepComponent: ImportStep;

  function onNetworkChange(newNetwork: Chain, oldNetwork: Chain) {
    updateForm();
    activeStep = BridgeSteps.IMPORT;
    if (newNetwork) {
      const destChainId = $destinationChain?.id;
      if (!destChainId) return;
      // determine if we simply swapped dest and src networks
      if (newNetwork.id === destChainId) {
        destinationChain.set(oldNetwork);
        return;
      }
      // A still-bridgeable destination stays selected; only an unreachable one is cleared
      if (!hasBridge(newNetwork.id, destChainId)) {
        $destinationChain = null;
      }
    }
  }

  const runValidations = async () => {
    importStepComponent?.revalidate();
    // Surfaces the paused modal via its store; the bridge classes enforce the actual block
    await isBridgePaused();
  };

  function onAccountChange(account: Account, oldAccount?: Account) {
    // A different wallet invalidates the import, the ownership check behind it, and the
    // recipient defaults. updateForm alone cannot do this: in manual mode it revalidates
    // through importStepComponent, which is unmounted on any step past IMPORT, so the
    // flow stayed on account A's NFT with account B connected.
    if (oldAccount && account?.address !== oldAccount?.address && activeStep !== BridgeSteps.IMPORT) {
      activeStep = BridgeSteps.IMPORT;
    }
    updateForm();
    if (account && account.isDisconnected) {
      $selectedToken = null;
      $destinationChain = null;
    }
  }

  /**
   * The recipient and the destination owner default to the connected wallet. They are not
   * import inputs, so a manual import that only revalidates still has to re-seed them:
   * re-entering the contract and ids for account B passed its own ownership check, while
   * Review went on showing account A as the recipient - tagged "customized" though nothing
   * had been - and would have bridged the NFT with A as its destination owner.
   */
  const seedAccountDefaults = () => {
    $recipientAddress = $account?.address || null;
    $destOwnerAddress = $account?.address || null;
  };

  function updateForm() {
    tick().then(() => {
      if ($selectedImportMethod === ImportMethod.MANUAL) {
        // The import inputs are revalidated rather than cleared - the contract and ids are
        // still worth checking against the new account or chain - but everything the old
        // account seeded is reset, the way the scan branch does through resetForm
        seedAccountDefaults();
        runValidations().catch((error) => console.error('Error running validations', error));
      } else {
        resetForm();
      }
    });
  }

  const resetForm = () => {
    // The fee is reset through its stores rather than a component ref: the ProcessingFee
    // instances live inside RecipientStep and ReviewStep, so nothing here could ever bind
    // one - the same never-bound-ref bug this file fixed for the address and id inputs.
    $processingFeeMethod = ProcessingFeeMethod.RECOMMENDED;
    $gasLimitZero = false;
    //we check if these are still mounted, as the user might have left the page
    importStepComponent?.resetManualImport();

    seedAccountDefaults();
    bridgingStatus = BridgingStatus.PENDING;
    $selectedToken = ETHToken;
    $importDone = false;
    $selectedNFTs = [];
    // The scan results are a store so they survive back-navigation, which also means they
    // survive a wallet or network change: ImportStep is unmounted past the import step, so
    // its own reset never runs, and it remounts showing the previous account's NFTs.
    $foundNFTs = [];
    $selectedImportMethod = ImportMethod.NONE;
    activeStep = BridgeSteps.IMPORT;
  };

  const handleTransactionDetailsClick = () => (activeStep = BridgeSteps.RECIPIENT);

  // Whenever the user switches bridge types, we should reset the forms
  $: $activeBridge && (resetForm(), (activeStep = BridgeSteps.IMPORT));

  // Set the content text based on the current step
  $: {
    const stepKey = BridgeSteps[activeStep].toLowerCase();
    if (activeStep === BridgeSteps.CONFIRM) {
      nftStepTitle = '';
      nftStepDescription = '';
    } else {
      nftStepTitle = $t(`bridge.title.nft.${stepKey}`);
      nftStepDescription = $t(`bridge.description.nft.${stepKey}`);
    }
  }

  $: validatingImport = false;

  // Only a completed bridge wipes the form when landing back on IMPORT; plain
  // back-navigation must keep the user's input. Clearing the flag as the wipe fires makes
  // it one-shot: bridgingStatus is only reset to PENDING in ConfirmationStep's onMount,
  // which does not run again until the CONFIRM step, so a stale DONE otherwise re-fired
  // this on every later step change.
  $: if (activeStep === BridgeSteps.IMPORT && bridgingStatus === BridgingStatus.DONE) {
    bridgingStatus = BridgingStatus.PENDING;
    resetForm();
  }

  onDestroy(() => {
    resetForm();
  });
</script>

<div class=" gap-0 w-full md:w-[524px]">
  <Stepper {activeStep}>
    <Step stepIndex={BridgeSteps.IMPORT} currentStepIndex={activeStep} isActive={activeStep === BridgeSteps.IMPORT}
      >{$t('bridge.step.import.title')}</Step>
    <Step stepIndex={BridgeSteps.REVIEW} currentStepIndex={activeStep} isActive={activeStep === BridgeSteps.REVIEW}
      >{$t('bridge.step.review.title')}</Step>
    <Step stepIndex={BridgeSteps.CONFIRM} currentStepIndex={activeStep} isActive={activeStep === BridgeSteps.CONFIRM}
      >{$t('bridge.step.confirm.title')}</Step>
  </Stepper>

  <Card class="md:mt-[32px] w-full md:w-[524px]" title={nftStepTitle} text={nftStepDescription}>
    <div class="space-y-[30px]">
      {#if activeStep === BridgeSteps.IMPORT}
        <!-- IMPORT STEP -->
        <ImportStep bind:this={importStepComponent} bind:validating={validatingImport} />
      {:else if activeStep === BridgeSteps.REVIEW}
        <!-- REVIEW STEP -->
        <ReviewStep on:editTransactionDetails={handleTransactionDetailsClick} bind:hasEnoughEth />
      {:else if activeStep === BridgeSteps.RECIPIENT}
        <!-- RECIPIENT STEP -->
        <RecipientStep bind:this={recipientStepComponent} bind:hasEnoughEth />
      {:else if activeStep === BridgeSteps.CONFIRM}
        <!-- CONFIRM STEP -->
        <ConfirmationStep bind:bridgingStatus />
      {/if}
      <!-- NAVIGATION -->
      <StepNavigation bind:activeStep {validatingImport} {bridgingStatus} />
    </div>
  </Card>
</div>

<OnNetwork change={onNetworkChange} />
<OnAccount change={onAccountChange} />

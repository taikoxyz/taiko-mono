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
  import { ETHToken } from '$libs/token';
  import { isBridgePaused } from '$libs/util/checkForPausedContracts';
  import { type Account, account } from '$stores/account';

  import { ImportStep, ReviewStep, StepNavigation } from './NFTBridgeComponents';
  import { selectedImportMethod } from './NFTBridgeComponents/ImportStep/state';
  import { ConfirmationStep, RecipientStep } from './SharedBridgeComponents';
  import type { ProcessingFee } from './SharedBridgeComponents/ProcessingFee';
  import {
    activeBridge,
    destNetwork as destinationChain,
    destOwnerAddress,
    importDone,
    recipientAddress,
    selectedNFTs,
    selectedToken,
  } from './state';
  import { BridgeSteps } from './types';

  let recipientStepComponent!: RecipientStep;
  let processingFeeComponent!: ProcessingFee;
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

  function onAccountChange(account: Account) {
    updateForm();
    if (account && account.isDisconnected) {
      $selectedToken = null;
      $destinationChain = null;
    }
  }

  function updateForm() {
    tick().then(() => {
      if ($selectedImportMethod === ImportMethod.MANUAL) {
        // run validations again if we are in manual mode
        runValidations().catch((error) => console.error('Error running validations', error));
      } else {
        resetForm();
      }
    });
  }

  const resetForm = () => {
    //we check if these are still mounted, as the user might have left the page
    if (processingFeeComponent) processingFeeComponent.resetProcessingFee();
    importStepComponent?.resetManualImport();

    $recipientAddress = $account?.address || null;
    $destOwnerAddress = $account?.address || null;
    bridgingStatus = BridgingStatus.PENDING;
    $selectedToken = ETHToken;
    $importDone = false;
    $selectedNFTs = [];
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

  // Only a completed bridge wipes the form when landing back on IMPORT;
  // plain back-navigation must keep the user's input
  $: if (activeStep === BridgeSteps.IMPORT && bridgingStatus === BridgingStatus.DONE) {
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

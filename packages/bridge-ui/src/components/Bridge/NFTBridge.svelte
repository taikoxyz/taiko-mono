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
  import { BridgePausedError } from '$libs/error';
  import { ETHToken } from '$libs/token';
  import { isBridgePaused } from '$libs/util/checkForPausedContracts';
  import { type Account, account } from '$stores/account';

  import { ImportStep, ReviewStep, StepNavigation } from './NFTBridgeComponents';
  import type IdInput from './NFTBridgeComponents/IDInput/IDInput.svelte';
  import { ConfirmationStep, RecipientStep } from './SharedBridgeComponents';
  import type AddressInput from './SharedBridgeComponents/AddressInput/AddressInput.svelte';
  import type { ProcessingFee } from './SharedBridgeComponents/ProcessingFee';
  import {
    activeBridge,
    destNetwork as destinationChain,
    importDone,
    recipientAddress,
    selectedNFTs,
    selectedToken,
  } from './state';
  import { BridgeSteps } from './types';

  let recipientStepComponent: RecipientStep;
  let processingFeeComponent: ProcessingFee;
  let importMethod: ImportMethod;
  let bridgingStatus: BridgingStatus;

  let hasEnoughEth: boolean = false;
  let activeStep: BridgeSteps = BridgeSteps.IMPORT;

  let nftStepTitle: string;
  let nftStepDescription: string;

  let addressInputComponent: AddressInput;
  let nftIdInputComponent: IdInput;

  function onNetworkChange(newNetwork: Chain, oldNetwork: Chain) {
    updateForm();
    activeStep = BridgeSteps.IMPORT;
    if (newNetwork) {
      const destChainId = $destinationChain?.id;
      if (!$destinationChain?.id) return;
      // determine if we simply swapped dest and src networks
      if (newNetwork.id === destChainId) {
        destinationChain.set(oldNetwork);
        return;
      }
      // check if the new network has a bridge to the current dest network
      if (hasBridge(newNetwork.id, $destinationChain?.id)) {
        destinationChain.set(oldNetwork);
      } else {
        // if not, set dest network to null
        $destinationChain = null;
      }
    }
  }

  const runValidations = () => {
    if (addressInputComponent) addressInputComponent.validateAddress();
    isBridgePaused().then((paused) => {
      if (paused) {
        throw new BridgePausedError();
      }
    });
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
      if (importMethod === ImportMethod.MANUAL) {
        // run validations again if we are in manual mode
        runValidations();
      } else {
        resetForm();
      }
    });
  }

  const resetForm = () => {
    //we check if these are still mounted, as the user might have left the page
    if (processingFeeComponent) processingFeeComponent.resetProcessingFee();
    if (addressInputComponent) addressInputComponent.clearAddress();

    // Update balance after bridging
    if (nftIdInputComponent) nftIdInputComponent.clearIds();

    $recipientAddress = $account?.address || null;
    bridgingStatus = BridgingStatus.PENDING;
    $selectedToken = ETHToken;
    importMethod === null;
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

  $: activeStep === BridgeSteps.IMPORT && resetForm();

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
        <ImportStep bind:validating={validatingImport} />
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

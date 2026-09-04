<script lang="ts">
  import { t } from 'svelte-i18n';

  import { Card } from '$components/Card';
  import { OnAccount } from '$components/OnAccount';
  import { OnNetwork } from '$components/OnNetwork';
  import { Step, Stepper } from '$components/Stepper';
  import { type Account, connectedSmartContractWallet } from '$stores/account';

  import { ImportStep, ReviewStep, StepNavigation } from './FungibleBridgeComponents';
  import { ConfirmationStep, RecipientStep } from './SharedBridgeComponents';
  import { BridgeSteps, BridgingStatus } from './types';

  const handleTransactionDetailsClick = () => (activeStep = BridgeSteps.RECIPIENT);
  const handleBackClick = () => (activeStep = BridgeSteps.IMPORT);

  let activeStep: BridgeSteps = BridgeSteps.IMPORT;
  let recipientStepComponent: RecipientStep;

  let stepTitle: string;
  let stepDescription: string;

  let hasEnoughEth: boolean = false;
  let hasEnoughFundsToContinue: boolean = false;
  let bridgingStatus: BridgingStatus;
  let needsManualReviewConfirmation: boolean;

  $: needsManualRecipientConfirmation = $connectedSmartContractWallet;

  // A wallet network or account change invalidates what Review/Confirm show,
  // so the wizard returns to the import step for revalidation
  function onNetworkChange() {
    if (activeStep !== BridgeSteps.IMPORT) {
      activeStep = BridgeSteps.IMPORT;
    }
  }

  function onAccountChange(newAccount: Account, oldAccount?: Account) {
    if (oldAccount && newAccount?.address !== oldAccount?.address && activeStep !== BridgeSteps.IMPORT) {
      activeStep = BridgeSteps.IMPORT;
    }
  }

  $: {
    const stepKey = BridgeSteps[activeStep].toLowerCase();
    if (activeStep === BridgeSteps.CONFIRM) {
      stepTitle = '';
      stepDescription = '';
    } else {
      stepTitle = $t(`bridge.title.fungible.${stepKey}`);
      stepDescription = $t(`bridge.description.fungible.${stepKey}`);
    }
  }
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

  <Card class="md:mt-[32px] w-full md:w-[524px]" title={stepTitle} text={stepDescription}>
    <div class="space-y-[30px] mt-[30px]">
      {#if activeStep === BridgeSteps.IMPORT}
        <!-- IMPORT STEP -->
        <ImportStep bind:hasEnoughEth />
      {:else if activeStep === BridgeSteps.REVIEW}
        <!-- REVIEW STEP -->
        <ReviewStep
          on:editTransactionDetails={handleTransactionDetailsClick}
          on:goBack={handleBackClick}
          bind:needsManualReviewConfirmation
          bind:hasEnoughEth
          bind:hasEnoughFundsToContinue />
      {:else if activeStep === BridgeSteps.RECIPIENT}
        <!-- RECIPIENT STEP -->
        <RecipientStep bind:this={recipientStepComponent} bind:hasEnoughEth bind:needsManualRecipientConfirmation />
      {:else if activeStep === BridgeSteps.CONFIRM}
        <!-- CONFIRM STEP -->
        <ConfirmationStep bind:bridgingStatus />
      {/if}
      <!-- NAVIGATION -->
      <StepNavigation
        bind:activeStep
        bind:hasEnoughFundsToContinue
        {bridgingStatus}
        bind:needsManualReviewConfirmation
        bind:needsManualRecipientConfirmation />
    </div>
  </Card>
</div>

<OnNetwork change={onNetworkChange} />
<OnAccount change={onAccountChange} />

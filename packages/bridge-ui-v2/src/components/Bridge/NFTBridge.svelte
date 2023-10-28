<script lang="ts">
  import { onDestroy, tick } from 'svelte';
  import { t } from 'svelte-i18n';
  import { type Address, isAddress } from 'viem';

  import { Button } from '$components/Button';
  import { Card } from '$components/Card';
  import { OnAccount } from '$components/OnAccount';
  import { OnNetwork } from '$components/OnNetwork';
  import { Step, Stepper } from '$components/Stepper';
  import { hasBridge } from '$libs/bridge/bridges';
  import { ETHToken, type NFT } from '$libs/token';
  import { fetchNFTImageUrl } from '$libs/token/fetchNFTImageUrl';
  import { getTokenWithInfoFromAddress } from '$libs/token/getTokenWithInfoFromAddress';
  import { type Account, account } from '$stores/account';
  import { type Network, network } from '$stores/network';

  import type AddressInput from './AddressInput/AddressInput.svelte';
  import type Amount from './Amount.svelte';
  import type IdInput from './IDInput/IDInput.svelte';
  import ConfirmationStep from './NFTBridgeSteps/ConfirmationStep.svelte';
  import ImportStep from './NFTBridgeSteps/ImportStep.svelte';
  import RecipientStep from './NFTBridgeSteps/RecipientStep.svelte';
  import ReviewStep from './NFTBridgeSteps/ReviewStep.svelte';
  import type { ProcessingFee } from './ProcessingFee';
  import { activeBridge, destNetwork as destinationChain, selectedNFTs, selectedToken } from './state';
  import { NFTSteps } from './types';

  let amountComponent: Amount;
  let recipientStepComponent: RecipientStep;
  let processingFeeComponent: ProcessingFee;
  let importMethod: 'scan' | 'manual' = 'scan';
  let nftIdArray: number[] = [];
  let contractAddress: Address | string = '';
  let bridgingStatus: 'pending' | 'done' = 'pending';

  function onNetworkChange(newNetwork: Network, oldNetwork: Network) {
    updateForm();
    activeStep = NFTSteps.CONFIRM;
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
    if (amountComponent) amountComponent.validateAmount();
    if (addressInputComponent) addressInputComponent.validateAddress();
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
      if (importMethod === 'manual') {
        // run validations again if we are in manual mode
        runValidations();
      } else {
        resetForm();
      }
    });
  }

  // async function approve() {
  //   try {
  //     if (!$selectedToken || !$network || !$destinationChain) return;
  //     const type: TokenType = $selectedToken.type;
  //     const walletClient = await getConnectedWallet($network.id);
  //     let tokenAddress = await getAddress($selectedToken.addresses[$network.id]);

  //     if (!tokenAddress) {
  //       const crossChainAddress = await getCrossChainAddress({
  //         token: $selectedToken,
  //         srcChainId: $network.id,
  //         destChainId: $destinationChain.id,
  //       });
  //       if (!crossChainAddress) throw new Error('cross chain address not found');
  //       tokenAddress = crossChainAddress;
  //     }
  //     if (!tokenAddress) {
  //       throw new Error('token address not found');
  //     }
  //     const tokenIds =
  //       nftIdArray.length > 0
  //         ? nftIdArray.map((num) => BigInt(num))
  //         : $selectedNFTs && $selectedNFTs.map((nft) => BigInt(nft.tokenId));

  //     let txHash: Hash;

  //     const spenderAddress =
  //       type === TokenType.ERC1155
  //         ? routingContractsMap[$network.id][$destinationChain.id].erc1155VaultAddress
  //         : routingContractsMap[$network.id][$destinationChain.id].erc721VaultAddress;

  //     const args: NFTApproveArgs = { tokenIds: tokenIds!, tokenAddress, spenderAddress, wallet: walletClient };
  //     txHash = await (bridges[type] as ERC721Bridge | ERC1155Bridge).approve(args);

  //     const { explorer } = chainConfig[$network.id].urls;

  //     if (txHash)
  //       infoToast({
  //         title: $t('bridge.actions.approve.tx.title'),
  //         message: $t('bridge.actions.approve.tx.message', {
  //           values: {
  //             token: $selectedToken.symbol,
  //             url: `${explorer}/tx/${txHash}`,
  //           },
  //         }),
  //       });

  //     await pendingTransactions.add(txHash, $network.id);

  //     actionsComponent.checkTokensApproved();

  //     successToast({
  //       title: $t('bridge.actions.approve.success.title'),
  //       message: $t('bridge.actions.approve.success.message', {
  //         values: {
  //           token: $selectedToken.symbol,
  //         },
  //       }),
  //     });
  //   } catch (err) {
  //     console.error(err);
  //     handleBridgeError(err as Error);
  //   }
  // }

  // async function bridge() {
  //   if (!$bridgeService || !$selectedToken || !$network || !$destinationChain || !$account?.address) return;

  //   try {
  //     const walletClient = await getConnectedWallet($network.id);
  //     const commonArgs = {
  //       to: $recipientAddress || $account.address,
  //       wallet: walletClient,
  //       srcChainId: $network.id,
  //       destChainId: $destinationChain.id,
  //       fee: $processingFee,
  //     };

  //     const tokenIds =
  //       nftIdArray.length > 0
  //         ? nftIdArray.map((num) => BigInt(num))
  //         : $selectedNFTs && $selectedNFTs.map((nft) => BigInt(nft.tokenId));

  //     const bridgeArgs = await getBridgeArgs($selectedToken, $enteredAmount, commonArgs, nftIdArray);

  //     const args = { ...bridgeArgs, tokenIds };

  //     bridgeTxHash = await $bridgeService.bridge(args);
  //     activeStep = NFTSteps.CONFIRM;

  //     //TODO: everything below should be handled differently for the stepper design. Still tbd
  //   } catch (err) {
  //     console.error(err);
  //     handleBridgeError(err as Error);
  //   }
  // }

  $: if ($selectedToken && amountComponent) {
    amountComponent.validateAmount();
  }

  const resetForm = () => {
    //we check if these are still mounted, as the user might have left the page
    if (amountComponent) amountComponent.clearAmount();
    if (processingFeeComponent) processingFeeComponent.resetProcessingFee();
    if (addressInputComponent) addressInputComponent.clearAddress();
    if (recipientStepComponent) recipientStepComponent.reset();

    // Update balance after bridging
    if (amountComponent) amountComponent.updateBalance();
    if (nftIdInputComponent) nftIdInputComponent.clearIds();

    $selectedToken = ETHToken;
    importMethod === null;
    scanned = false;
    canProceed = false;
    $selectedNFTs = [];
    activeStep = NFTSteps.IMPORT;
  };

  /**
   *   NFT Bridge specific
   */
  let activeStep: NFTSteps = NFTSteps.IMPORT;

  const nextStep = () => (activeStep = Math.min(activeStep + 1, NFTSteps.CONFIRM));
  const previousStep = () => (activeStep = Math.max(activeStep - 1, NFTSteps.IMPORT));

  let nftStepTitle: string;
  let nftStepDescription: string;
  let nextStepButtonText: string;

  let addressInputComponent: AddressInput;
  let nftIdInputComponent: IdInput;

  let validatingImport: boolean = false;
  let scanned: boolean = false;

  let canProceed: boolean = false;
  let foundNFTs: NFT[] = [];

  const getStepText = () => {
    if (activeStep === NFTSteps.REVIEW) {
      return $t('common.confirm');
    }
    if (activeStep === NFTSteps.CONFIRM) {
      return $t('common.ok');
    } else {
      return $t('common.continue');
    }
  };

  const changeImportMethod = () => {
    importMethod = importMethod === 'manual' ? 'scan' : 'manual';
    resetForm();
  };

  const prefetchImage = async () => {
    await Promise.all(
      nftIdArray.map(async (id) => {
        const token = $selectedToken as NFT;
        if (token) {
          token.tokenId = id;
          fetchNFTImageUrl(token).then((nftWithUrl) => {
            $selectedToken = nftWithUrl;
            $selectedNFTs = [nftWithUrl];
          });
        } else {
          throw new Error('no token');
        }
      }),
    );
  };

  const manualImportAction = () => {
    if (!$network?.id) throw new Error('network not found');
    const srcChainId = $network?.id;
    const tokenId = nftIdArray[0];

    if (isAddress(contractAddress) && srcChainId)
      getTokenWithInfoFromAddress({ contractAddress, srcChainId: srcChainId, tokenId, owner: $account?.address })
        .then(async (token) => {
          if (!token) throw new Error('no token with info');
          // detectedTokenType = token.type;
          // idInputState = IDInputState.VALID;
          $selectedToken = token;
          await prefetchImage();
          nextStep();
        })
        .catch((err) => {
          console.error(err);
          // detectedTokenType = null;
          // idInputState = IDInputState.INVALID;
          // invalidToken = true;
        });
  };

  const handleTransactionDetailsClick = () => {
    activeStep = NFTSteps.RECIPIENT;
  };

  // Whenever the user switches bridge types, we should reset the forms
  $: $activeBridge && (resetForm(), (activeStep = NFTSteps.IMPORT));

  // Set the content text based on the current step
  $: {
    const stepKey = NFTSteps[activeStep].toLowerCase();
    nftStepTitle = $t(`bridge.title.nft.${stepKey}`);
    nftStepDescription = $t(`bridge.description.nft.${stepKey}`);
    nextStepButtonText = getStepText();
  }

  onDestroy(() => {
    resetForm();
  });
</script>

<div class="f-col">
  <Stepper {activeStep}>
    <Step stepIndex={NFTSteps.IMPORT} currentStepIndex={activeStep} isActive={activeStep === NFTSteps.IMPORT}
      >{$t('bridge.nft.step.import.title')}</Step>
    <Step stepIndex={NFTSteps.REVIEW} currentStepIndex={activeStep} isActive={activeStep === NFTSteps.REVIEW}
      >{$t('bridge.nft.step.review.title')}</Step>
    <Step stepIndex={NFTSteps.CONFIRM} currentStepIndex={activeStep} isActive={activeStep === NFTSteps.CONFIRM}
      >{$t('bridge.nft.step.confirm.title')}</Step>
  </Stepper>
  <button on:click={() => (activeStep = NFTSteps.CONFIRM)} class="flex justify-center py-3 link">
    {$t('bridge.nft.step.confirm.button.back')}
  </button>
  <Card class="mt-[32px] w-full md:w-[524px]" title={nftStepTitle} text={nftStepDescription}>
    <div class="space-y-[30px]">
      <!-- IMPORT STEP -->
      {#if activeStep === NFTSteps.IMPORT}
        <ImportStep
          bind:importMethod
          bind:canProceed
          bind:nftIdArray
          bind:contractAddress
          bind:foundNFTs
          bind:scanned
          bind:validating={validatingImport} />
        <!-- REVIEW STEP -->
      {:else if activeStep === NFTSteps.REVIEW}
        <ReviewStep on:editTransactionDetails={handleTransactionDetailsClick} />
        <!-- CONFIRM STEP -->
      {:else if activeStep === NFTSteps.RECIPIENT}
        <RecipientStep bind:this={recipientStepComponent} />
      {:else if activeStep === NFTSteps.CONFIRM}
        <ConfirmationStep bind:bridgingStatus />
      {/if}
      <!-- 
        User Actions
      -->
      {#if activeStep === NFTSteps.REVIEW}
        <div class="f-col w-full gap-4">
          <Button
            disabled={!canProceed}
            type="primary"
            class="px-[28px] py-[14px] rounded-full flex-1 w-auto text-white"
            on:click={() => (activeStep = NFTSteps.CONFIRM)}
            ><span class="body-bold">{nextStepButtonText}</span></Button>

          <button on:click={previousStep} class="flex justify-center py-3 link">
            {$t('common.back')}
          </button>
        </div>
      {:else if activeStep === NFTSteps.IMPORT}
        {#if importMethod === 'manual'}
          <div class="h-sep" />

          <div class="f-col w-full">
            <Button
              disabled={!canProceed}
              loading={validatingImport}
              type="primary"
              class="px-[28px] py-[14px] rounded-full flex-1 w-auto text-white"
              on:click={manualImportAction}><span class="body-bold">{nextStepButtonText}</span></Button>

            <button on:click={() => changeImportMethod()} class="flex justify-center py-3 link">
              {$t('common.back')}
            </button>
          </div>
        {:else if scanned}
          <div class="f-col w-full">
            <div class="h-sep" />

            <Button
              disabled={!canProceed}
              type="primary"
              class="px-[28px] py-[14px] rounded-full flex-1 w-auto text-white"
              on:click={nextStep}><span class="body-bold">{nextStepButtonText}</span></Button>

            <button on:click={resetForm} class="flex justify-center py-3 link">
              {$t('common.back')}
            </button>
          </div>
        {/if}
      {:else if activeStep === NFTSteps.RECIPIENT}
        <div class="f-col w-full">
          <Button
            disabled={!canProceed}
            type="primary"
            class="px-[28px] py-[14px] rounded-full flex-1 w-auto text-white"
            on:click={() => (activeStep = NFTSteps.REVIEW)}><span class="body-bold">{nextStepButtonText}</span></Button>

          <button on:click={previousStep} class="flex justify-center py-3 link">
            {$t('common.back')}
          </button>
        </div>
      {:else if activeStep === NFTSteps.CONFIRM}
        <div class="f-col w-full">
          {#if bridgingStatus === 'done'}
            <Button
              type="primary"
              class="px-[28px] py-[14px] rounded-full flex-1 w-auto text-white"
              on:click={resetForm}><span class="body-bold">{$t('bridge.nft.step.confirm.button.back')}</span></Button>
          {:else}
            <button on:click={resetForm} class="flex justify-center py-3 link">
              {$t('common.back')}
            </button>
          {/if}
        </div>
      {/if}
    </div>
  </Card>
</div>

<OnNetwork change={onNetworkChange} />
<OnAccount change={onAccountChange} />

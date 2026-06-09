"use client";

import { useRef, useState } from "react";
import { type Address, isAddress } from "viem";

import { FlatAlert } from "@/components/Alert";
import IdInput, {
  type IDInputHandle,
} from "@/components/Bridge/NFTBridgeComponents/IDInput/IDInput";
import { IDInputState } from "@/components/Bridge/NFTBridgeComponents/IDInput/state";
import TokenAmountInput, {
  type TokenAmountInputHandle,
} from "@/components/Bridge/NFTBridgeComponents/ImportStep/TokenAmountInput";
import AddressInput, {
  type AddressInputHandle,
} from "@/components/Bridge/SharedBridgeComponents/AddressInput/AddressInput";
import { AddressInputState } from "@/components/Bridge/SharedBridgeComponents/AddressInput/state";
import {
  enteredAmount,
  importDone,
  selectedNFTs,
  selectedToken,
  tokenBalance,
  useBridgeState,
} from "@/components/Bridge/state";
import { useTranslation } from "@/i18n/useTranslation";
import { detectContractType, type NFT, TokenType } from "@/libs/token";
import { checkOwnership } from "@/libs/token/checkOwnership";
import { getTokenWithInfoFromAddress } from "@/libs/token/getTokenWithInfoFromAddress";
import { account } from "@/stores/account";
import { connectedSourceChain } from "@/stores/network";

export interface ManualImportProps {
  /** Two-way bound `contractAddress` (Svelte `bind:ethereumAddress`). */
  contractAddress?: Address | string;
  onContractAddressChange?: (value: Address | string) => void;
  /** Two-way bound `nftIdsToImport` (Svelte `bind:validIdNumbers`). */
  nftIdsToImport?: number[];
  onNftIdsToImportChange?: (value: number[]) => void;
  /** Two-way bound `validating` (Svelte `bind:validating`). */
  validating?: boolean;
  onValidatingChange?: (value: boolean) => void;
}

export default function ManualImport({
  contractAddress: contractAddressProp = "",
  onContractAddressChange,
  nftIdsToImport: nftIdsToImportProp = [],
  onNftIdsToImportChange,
  validating = false,
  onValidatingChange,
}: ManualImportProps) {
  const { t } = useTranslation();

  // Local two-way state seeded from props (mirrors svelte `export let` defaults).
  const [contractAddress, setContractAddressLocal] = useState<Address | string>(
    contractAddressProp,
  );
  const [nftIdsToImport, setNftIdsToImportLocal] =
    useState<number[]>(nftIdsToImportProp);

  const setContractAddress = (v: Address | string) => {
    setContractAddressLocal(v);
    onContractAddressChange?.(v);
  };
  const setNftIdsToImport = (v: number[]) => {
    setNftIdsToImportLocal(v);
    onNftIdsToImportChange?.(v);
  };
  const setValidating = (v: boolean) => onValidatingChange?.(v);

  const [addressInputState, setAddressInputState] = useState<AddressInputState>(
    AddressInputState.DEFAULT,
  );

  // bind:this handles (unused imperatively here but kept for parity).
  const addressInputComponent = useRef<AddressInputHandle>(null);
  const amountComponent = useRef<TokenAmountInputHandle>(null);
  const nftIdInputComponent = useRef<IDInputHandle>(null);

  const [idInputState, setIdInputState] = useState<IDInputState>(
    IDInputState.DEFAULT,
  );
  const [enteredIds, setEnteredIds] = useState<number[]>([]);
  const [detectedTokenType, setDetectedTokenType] = useState<TokenType | null>(
    null,
  );
  const [isOwnerOfAllToken, setIsOwnerOfAllToken] = useState(false);

  const $selectedNFTs = useBridgeState(selectedNFTs);
  const $tokenBalance = useBridgeState(tokenBalance);
  const $enteredAmount = useBridgeState(enteredAmount);

  async function onAddressValidation(detail: {
    isValidEthereumAddress: boolean;
    addr: Address | string;
  }) {
    const { isValidEthereumAddress, addr } = detail;
    // interfaceSupported = true;
    setAddressInputState(AddressInputState.VALIDATING);

    const srcChainId = connectedSourceChain.getState()?.id;
    if (!srcChainId) return;

    let nextTokenType = detectedTokenType;

    if (isValidEthereumAddress && typeof addr === "string") {
      setContractAddress(addr);
      try {
        nextTokenType = await detectContractType(addr as Address, srcChainId);
        setDetectedTokenType(nextTokenType);
      } catch {
        setAddressInputState(AddressInputState.INVALID);
      }
      if (!connectedSourceChain.getState()?.id)
        throw new Error("network not found");
      if (
        nextTokenType !== TokenType.ERC721 &&
        nextTokenType !== TokenType.ERC1155
      ) {
        setAddressInputState(AddressInputState.NOT_NFT);
        return;
      }

      setAddressInputState(AddressInputState.VALID);
    } else {
      setDetectedTokenType(null);
      setAddressInputState(AddressInputState.INVALID);
    }
    return;
  }

  async function onIdInput(): Promise<void> {
    setIdInputState(IDInputState.VALIDATING);
    setValidating(true);

    let nextIdInputState = IDInputState.VALIDATING;
    let nextTokenType = detectedTokenType;

    try {
      const canValidate =
        isAddress(contractAddress) &&
        connectedSourceChain.getState()?.id &&
        account.getState()?.address
          ? true
          : false;
      if (canValidate && enteredIds && enteredIds.length > 0) {
        const tokenId = nftIdsToImport[0]; // Handle multiple tokens if needed

        const ownershipResults = await checkOwnership(
          contractAddress as Address,
          detectedTokenType,
          nftIdsToImport,
          // Ignore as we check this in canValidate
          // eslint-disable-next-line @typescript-eslint/no-non-null-asserted-optional-chain
          account.getState()?.address!,
          // Ignore as we check this in canValidate
          // eslint-disable-next-line @typescript-eslint/no-non-null-asserted-optional-chain
          connectedSourceChain.getState()?.id!,
        );

        const ownsAll = ownershipResults.every(
          (value) => value.isOwner === true,
        );
        setIsOwnerOfAllToken(ownsAll);

        if (!ownsAll) {
          nextIdInputState = IDInputState.INVALID;
          setIdInputState(IDInputState.INVALID);
          throw new Error("Not owner of all tokens");
        }
        const token = await getTokenWithInfoFromAddress({
          contractAddress: contractAddress as Address,
          // Ignore as we check this in canValidate
          // eslint-disable-next-line @typescript-eslint/no-non-null-asserted-optional-chain
          srcChainId: connectedSourceChain.getState()?.id!,
          tokenId,
          owner: account.getState()?.address,
        });

        if (!token) {
          throw new Error("No token with info");
        }

        nextTokenType = token.type;
        setDetectedTokenType(token.type);
        selectedNFTs.setState([token as NFT]);
        selectedToken.setState(token);
        nextIdInputState = IDInputState.VALID;
        setIdInputState(IDInputState.VALID);
      } else {
        nextIdInputState = IDInputState.INVALID;
        setIdInputState(IDInputState.INVALID);
      }
    } catch (err) {
      console.error(err);
      setDetectedTokenType(null);
      nextTokenType = null;
      nextIdInputState = IDInputState.INVALID;
      setIdInputState(IDInputState.INVALID);
    } finally {
      if (nextIdInputState !== IDInputState.VALID) {
        setIdInputState(IDInputState.DEFAULT);
      }
    }
    void nextTokenType;
    setValidating(false);
  }

  // Reactive derivations ($:)
  const displayOwnershipError = Boolean(
    contractAddress &&
      enteredIds &&
      !isOwnerOfAllToken &&
      nftIdsToImport?.length > 0 &&
      !validating,
  );

  const isERC1155 = detectedTokenType === TokenType.ERC1155;

  const hasEnteredIds = Boolean(enteredIds && enteredIds.length > 0);
  const hasSelectedNFT = Boolean(
    $selectedNFTs && $selectedNFTs.length > 0 && hasEnteredIds,
  );

  const nftHasAmount = hasSelectedNFT && isERC1155;

  const validBalance = Boolean(
    $tokenBalance &&
      $enteredAmount > 0 &&
      $enteredAmount <= $tokenBalance.value,
  );

  const commonChecks =
    Boolean(enteredIds && enteredIds.length > 0) &&
    !validating &&
    idInputState === IDInputState.VALID &&
    isOwnerOfAllToken;

  const ERC1155Checks =
    commonChecks &&
    nftHasAmount !== null &&
    hasSelectedNFT !== null &&
    validBalance;

  const canProceed = isERC1155 ? ERC1155Checks : commonChecks;

  // $: if (canProceed) { $importDone = true } else { $importDone = false }
  importDone.setState(canProceed ? true : false);

  const showNFTAmountInput = nftHasAmount && isOwnerOfAllToken;

  const isDisabled =
    idInputState !== IDInputState.VALID ||
    addressInputState !== AddressInputState.VALID;

  return (
    <>
      <AddressInput
        ref={addressInputComponent}
        ethereumAddress={contractAddress}
        onEthereumAddressChange={setContractAddress}
        state={addressInputState}
        onStateChange={setAddressInputState}
        className="bg-neutral-background border-0 h-[56px]"
        onAddressValidation={onAddressValidation}
        labelText={t("inputs.address_input.label.contract")}
      />

      {/* {#if !interfaceSupported}
            <Alert type="error">TODO: token interface is not supported (link to docs?)</Alert>
          {/if} */}
      <div className="min-h-[20px] mt-[30px]">
        {/* TODO: currently hard limited to 1 */}
        <IdInput
          isDisabled={addressInputState !== AddressInputState.VALID}
          ref={nftIdInputComponent}
          enteredIds={enteredIds}
          onEnteredIdsChange={setEnteredIds}
          validIdNumbers={nftIdsToImport}
          onValidIdNumbersChange={setNftIdsToImport}
          state={idInputState}
          onStateChange={setIdInputState}
          onInputValidation={onIdInput}
          limit={1}
          className="bg-neutral-background border-0 h-[56px]"
        />
        <div className="min-h-[20px] !mt-3">
          {/* NOTE: original passed `forceColumnFlow`, but FlatAlert ignores it (no such prop) — omitted. */}
          {displayOwnershipError && (
            <FlatAlert
              type="error"
              message={t("bridge.errors.not_the_owner_of_all")}
            />
          )}
        </div>
      </div>
      {showNFTAmountInput && !isDisabled && (
        <TokenAmountInput ref={amountComponent} className="!mt-0" />
      )}
      <div className="h-sep" />
    </>
  );
}

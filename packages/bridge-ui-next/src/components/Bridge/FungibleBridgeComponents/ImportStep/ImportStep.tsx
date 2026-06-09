"use client";

import { useEffect, useState } from "react";

import {
  destOwnerAddress,
  importDone,
  processingFeeMethod,
  recipientAddress,
} from "@/components/Bridge/state";
import { ChainSelector, ChainSelectorType } from "@/components/ChainSelectors";
import { ProcessingFeeMethod } from "@/libs/fee";

import TokenInput from "./TokenInput/TokenInput";

export interface ImportStepProps {
  /** Two-way bound (Svelte `bind:hasEnoughEth`) forwarded down to TokenInput. */
  hasEnoughEth?: boolean;
  onHasEnoughEthChange?: (value: boolean) => void;
}

export default function ImportStep({
  hasEnoughEth = false,
  onHasEnoughEthChange,
}: ImportStepProps) {
  // Svelte `let validInput = false` driving `$: $importDone = validInput`.
  const [validInput, setValidInput] = useState(false);

  // onMount(async () => { reset(); })
  useEffect(() => {
    recipientAddress.setState(null);
    destOwnerAddress.setState(null);
    processingFeeMethod.setState(ProcessingFeeMethod.RECOMMENDED);
  }, []);

  // $: $importDone = validInput;
  useEffect(() => {
    importDone.setState(validInput);
  }, [validInput]);

  return (
    <>
      <ChainSelector type={ChainSelectorType.COMBINED} />

      <TokenInput
        validInput={validInput}
        onValidInputChange={setValidInput}
        hasEnoughEth={hasEnoughEth}
        onHasEnoughEthChange={onHasEnoughEthChange}
      />
    </>
  );
}

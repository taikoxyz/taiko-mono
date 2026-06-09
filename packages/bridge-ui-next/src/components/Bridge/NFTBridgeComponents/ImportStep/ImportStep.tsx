"use client";

import { useEffect, useRef, useState } from "react";

import {
  destNetwork as destChain,
  importDone,
  selectedNFTs,
  useBridgeState,
} from "@/components/Bridge/state";
import { ImportMethod } from "@/components/Bridge/types";
import { ChainSelector, ChainSelectorType } from "@/components/ChainSelectors";
import { OnAccount } from "@/components/OnAccount";
import { fetchNFTs } from "@/libs/bridge/fetchNFTs";
import type { NFT } from "@/libs/token";
import { account } from "@/stores/account";
import { connectedSourceChain as srcChain } from "@/stores/network";

import ImportActions from "./ImportActions";
import ManualImport from "./ManualImport";
import ScannedImport from "./ScannedImport";
import { selectedImportMethod, useSelectedImportMethod } from "./state";

export interface ImportStepProps {
  /** Two-way bound `validating` (Svelte `bind:validating`). */
  validating?: boolean;
  onValidatingChange?: (value: boolean) => void;
}

export default function ImportStep({
  validating = false,
  onValidatingChange,
}: ImportStepProps) {
  const [foundNFTs, setFoundNFTs] = useState<NFT[]>([]);

  // States
  const [scanning, setScanning] = useState(false);
  const [canProceed, setCanProceed] = useState(false);

  const $selectedImportMethod = useSelectedImportMethod();
  const $destChain = useBridgeState(destChain);

  // foundNFTs is read inside nextPage's pagination check via ScannedImport, but
  // the source scanForNFTs replaces it wholesale; keep a ref for stable reads.
  const foundNFTsRef = useRef<NFT[]>(foundNFTs);
  foundNFTsRef.current = foundNFTs;

  const nextPage = async () => {
    await scanForNFTs(false);
  };

  const scanForNFTs = async (refresh: boolean) => {
    setScanning(true);
    selectedNFTs.setState([]);
    const accountAddress = account.getState()?.address;
    const srcChainId = srcChain.getState()?.id;
    const destChainId = destChain.getState()?.id;
    if (!accountAddress || !srcChainId || !destChainId) return;
    const nftsFromAPIs = await fetchNFTs({
      address: accountAddress,
      chainId: srcChainId,
      refresh,
    });

    setFoundNFTs(nftsFromAPIs.nfts);

    setScanning(false);

    if (nftsFromAPIs.nfts.length > 0) {
      selectedImportMethod.setState(ImportMethod.SCAN);
    }
  };

  const reset = () => {
    setFoundNFTs([]);
    selectedNFTs.setState([]);
    selectedImportMethod.setState(ImportMethod.NONE);
  };

  const onAccountChange = () => {
    reset();
  };

  // $: canImport = ($account?.isConnected && $srcChain?.id && $destChain && !scanning) || false;
  const canImport = Boolean(
    account.getState()?.isConnected &&
      srcChain.getState()?.id &&
      $destChain &&
      !scanning,
  );

  // $: { if (canProceed) { $importDone = true } else { $importDone = false } }
  useEffect(() => {
    importDone.setState(canProceed ? true : false);
  }, [canProceed]);

  // onMount(() => { reset(); });
  useEffect(() => {
    reset();
  }, []);

  return (
    <>
      <div className="f-between-center gap-[16px] mt-[30px]">
        <ChainSelector type={ChainSelectorType.COMBINED} />
      </div>

      <div className="h-sep" />

      {$selectedImportMethod === ImportMethod.MANUAL ? (
        <ManualImport
          validating={validating}
          onValidatingChange={onValidatingChange}
        />
      ) : $selectedImportMethod === ImportMethod.SCAN ? (
        <ScannedImport
          refresh={() => scanForNFTs(true)}
          nextPage={nextPage}
          foundNFTs={foundNFTs}
          onFoundNFTsChange={setFoundNFTs}
          canProceed={canProceed}
          onCanProceedChange={setCanProceed}
        />
      ) : (
        <ImportActions
          scanning={scanning}
          onScanningChange={setScanning}
          canImport={canImport}
          scanForNFTs={() => scanForNFTs(false)}
        />
      )}

      <OnAccount change={onAccountChange} />
    </>
  );
}

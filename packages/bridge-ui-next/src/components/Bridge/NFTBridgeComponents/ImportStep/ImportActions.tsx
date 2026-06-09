"use client";

import { useEffect, useState } from "react";

import { Alert } from "@/components/Alert";
import { ImportMethod } from "@/components/Bridge/types";
import { ActionButton } from "@/components/Button";
import { useTranslation } from "@/i18n/useTranslation";

import { selectedImportMethod } from "./state";

export interface ImportActionsProps {
  canImport?: boolean;
  /** Two-way bound `scanning` (Svelte `bind:scanning`). */
  scanning?: boolean;
  onScanningChange?: (value: boolean) => void;
  scanForNFTs: () => Promise<void>;
}

export default function ImportActions({
  canImport = false,
  scanning = false,
  onScanningChange,
  scanForNFTs,
}: ImportActionsProps) {
  const { t } = useTranslation();

  const [firstScan, setFirstScan] = useState(false);

  function onScanClick() {
    onScanningChange?.(true);
    scanForNFTs().finally(() => {
      setFirstScan(false);
      onScanningChange?.(false);
    });
  }

  // onMount(() => { firstScan = true; });
  useEffect(() => {
    setFirstScan(true);
  }, []);

  return (
    <div className="f-col w-full gap-4">
      {firstScan ? (
        <>
          <ActionButton
            priority="primary"
            disabled={!canImport}
            loading={scanning}
            onClick={onScanClick}
          >
            {t("bridge.actions.nft_scan")}
          </ActionButton>

          <ActionButton
            priority="secondary"
            disabled={!canImport}
            onClick={() => selectedImportMethod.setState(ImportMethod.MANUAL)}
          >
            {t("bridge.actions.nft_manual")}
          </ActionButton>
        </>
      ) : (
        <>
          <ActionButton
            priority="secondary"
            disabled={!canImport}
            loading={scanning}
            onClick={() => {
              void (async () => {
                await scanForNFTs();
              })();
            }}
          >
            {t("bridge.actions.nft_scan_again")}
          </ActionButton>

          <ActionButton
            priority="primary"
            disabled={!canImport}
            onClick={() => selectedImportMethod.setState(ImportMethod.MANUAL)}
          >
            {t("bridge.actions.nft_manual")}
          </ActionButton>

          <Alert type="warning" forceColumnFlow className="mt-[16px]">
            <p>{t("bridge.nft.step.import.no_nft_found")}</p>
          </Alert>
        </>
      )}
    </div>
  );
}

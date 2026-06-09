"use client";

import { Icon } from "@/components/Icon";
import { useTranslation } from "@/i18n/useTranslation";
import { cn } from "@/lib/utils";
import { useModalStore } from "@/stores/useModalStore";

/**
 * React port of `components/BridgePausedModal/BridgePausedModal.svelte`.
 *
 * Self-contained daisyUI dialog whose visibility is driven by the
 * `bridgePausedModal` flag in the modal store (set imperatively from
 * `libs/util/checkForPausedContracts.ts`). DOM structure and class strings are
 * preserved verbatim for pixel parity.
 *
 * Svelte `class:modal-open={$bridgePausedModal}` -> `cn('modal ...', { 'modal-open': bridgePausedModal })`.
 * Svelte store `$bridgePausedModal` -> `useModalStore` selector.
 * Svelte `$t('...')` -> `t('...')`.
 */
export default function BridgePausedModal() {
  const { t } = useTranslation();
  const bridgePausedModal = useModalStore((state) => state.bridgePausedModal);

  return (
    <dialog
      className={cn("modal modal-bottom md:modal-middle", {
        "modal-open": bridgePausedModal,
      })}
    >
      <div className="modal-box relative px-6 py-[35px] md:py-[35px] bg-neutral-background text-primary-content box-shadow-small">
        <h3 className="title-body-bold mb-[30px]">{t("paused_modal.title")}</h3>
        <Icon
          type="info-circle"
          size={200}
          fillClass="fill-warning-sentiment"
          className="mb-4"
        />
        <p className="body-regular text-center mb-[20px]">
          {t("paused_modal.description")}
        </p>
      </div>
    </dialog>
  );
}

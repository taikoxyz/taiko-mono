"use client";

import type { CSSProperties, KeyboardEvent } from "react";
import { useMemo, useState } from "react";

import { Icon } from "@/components/Icon";
import { useTranslation } from "@/i18n/useTranslation";

export interface PaginatorProps {
  /** The currently active page (1-based). Controlled value. */
  currentPage?: number;
  /** Total number of items used to compute the page count. */
  totalItems?: number;
  /** Number of items shown per page. */
  pageSize?: number;
  /**
   * Callback fired when the user requests a page change.
   * Mirrors the Svelte `pageChange` event dispatch (emits the raw requested page).
   */
  onPageChange?: (page: number) => void;
}

// Scoped `.pagination` style from the original Paginator.svelte.
// NOTE: source declares `align-items` twice (flex-end then center); last wins => center.
const paginationStyle: CSSProperties = {
  justifyContent: "flex-end",
  alignItems: "center",
  gap: "10px",
  display: "flex",
};

const btnClass =
  "btn btn-xs btn-ghost disabled:bg-transparent disabled:cursor-not-allowed";

export default function Paginator({
  currentPage = 1,
  totalItems = 0,
  pageSize = 5,
  onPageChange,
}: PaginatorProps) {
  const { t } = useTranslation();

  // Local mirror of the bound `currentPage` value so the number input stays editable,
  // matching the original `bind:value={currentPage}` two-way binding.
  const [page, setPage] = useState(currentPage);

  const totalPages = useMemo(
    () => Math.max(1, Math.ceil(totalItems / pageSize)),
    [totalItems, pageSize],
  );

  function goToPage(requestedPage: number) {
    setPage(Math.min(totalPages, Math.max(1, requestedPage)));
    onPageChange?.(requestedPage);
  }

  function handleKeydown(event: KeyboardEvent<HTMLInputElement>) {
    if (event.key === "Enter") {
      const nextPage = parseInt((event.target as HTMLInputElement).value, 10);

      // Check if input is within the valid range, otherwise do nothing
      if (nextPage > 0 && nextPage <= totalPages) {
        goToPage(nextPage);
      }
    }
  }

  // Computed flags for first and last page
  const isFirstPage = page === 1;
  const isLastPage = page === totalPages;

  if (totalPages <= 1) {
    return null;
  }

  return (
    /* Show pagination buttons if needed */
    <div className="pagination btn-group pt-4" style={paginationStyle}>
      {/* Button to go to previous page */}
      <button
        disabled={isFirstPage}
        className={btnClass}
        onClick={() => goToPage(page - 1)}
      >
        <Icon type="chevron-left" />
      </button>
      {t("paginator.page")}
      <input
        type="number"
        className="form-control mx-1 text-center rounded-full bg-neutral-background border-none py-1 px-8"
        value={page}
        min={1}
        max={totalPages}
        onChange={(event) => setPage(Number(event.target.value))}
        onKeyDown={handleKeydown}
        onBlur={() => goToPage(page)}
      />
      {t("paginator.of")}
      {totalPages}
      {/* Button to go to next page */}
      <button
        disabled={isLastPage}
        className={btnClass}
        onClick={() => goToPage(page + 1)}
      >
        <Icon type="chevron-right" />
      </button>
    </div>
  );
}

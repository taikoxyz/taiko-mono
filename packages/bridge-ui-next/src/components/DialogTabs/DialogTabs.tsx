"use client";

import DialogTab from "./DialogTab";

export interface DialogTabsTab {
  id: string;
  title: string;
}

export interface DialogTabsProps {
  tabs: DialogTabsTab[];
  /**
   * The currently active tab id. Controlled value (Svelte `bind:activeTab`):
   * pair with `onActiveTabChange` to mirror the original two-way binding.
   */
  activeTab: string;
  /** Mirrors the Svelte local mutation of `activeTab` (two-way binding). */
  onActiveTabChange?: (tabId: string) => void;
  /** Svelte `dispatch('change', { tabId })` -> `onChange({ tabId })`. */
  onChange?: (detail: { tabId: string }) => void;
}

export default function DialogTabs({
  tabs,
  activeTab,
  onActiveTabChange,
  onChange,
}: DialogTabsProps) {
  function setActiveTab(tabId: string) {
    if (activeTab !== tabId) {
      onActiveTabChange?.(tabId);
      onChange?.({ tabId });
    }
  }

  return (
    <div role="tablist" className="tabs">
      {tabs.map((tab) => (
        <DialogTab
          key={tab.id}
          active={tab.id === activeTab}
          onClick={() => setActiveTab(tab.id)}
        >
          {tab.title}
        </DialogTab>
      ))}
    </div>
  );
}

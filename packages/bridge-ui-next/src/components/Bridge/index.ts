// Barrel for the Bridge component unit.
//
// The original Svelte index.ts only re-exported `Bridge`. `BridgeTabs` was imported
// directly from its file (`$components/Bridge/BridgeTabs.svelte`) by Header /
// SideNavigation; it is additionally re-exported here (named + default-friendly) so
// consumers can use either `@/components/Bridge/BridgeTabs` or this barrel.

export { default as Bridge } from "./Bridge";
export { default as BridgeTabs } from "./BridgeTabs";
export type { BridgeTabsProps } from "./BridgeTabs";

export { default } from "./Bridge";

import type { Metadata } from "next";

import { Faucet } from "@/components/Faucet";
import { Page } from "@/components/Page";

/**
 * /faucet route — mirrors src/routes/faucet/+page.svelte:
 *   <svelte:head><title>Taiko Bridge | Faucet</title></svelte:head>
 *   <Page><Faucet /></Page>
 *
 * NOTE: the faucet nav link is gated on NEXT_PUBLIC_TESTNET_NAME in
 * SideNavigation, matching the original; the route itself always exists.
 */
export const metadata: Metadata = {
  title: "Taiko Bridge | Faucet",
};

export default function FaucetPage() {
  return (
    <Page>
      <Faucet />
    </Page>
  );
}

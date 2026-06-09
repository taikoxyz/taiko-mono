import type { Metadata } from "next";

import { Page } from "@/components/Page";
import { Transactions } from "@/components/Transactions";

/**
 * /transactions route — mirrors src/routes/transactions/+page.svelte:
 *   <svelte:head><title>Taiko Bridge | Transactions</title></svelte:head>
 *   <Page><Transactions /></Page>
 */
export const metadata: Metadata = {
  title: "Taiko Bridge | Transactions",
};

export default function TransactionsPage() {
  return (
    <Page>
      <Transactions />
    </Page>
  );
}

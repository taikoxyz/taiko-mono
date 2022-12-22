import { _, dictionary, locale } from "svelte-i18n";

function setupI18n({ withLocale: _locale } = { withLocale: "en" }) {
  dictionary.set({
    en: {
      home: {
        title: "Taiko Bridge",
        selectToken: "Select Token",
        to: "To",
        bridge: "Bridge",
        approve: "Approve",
      },
      bridgeForm: {
        fieldLabel: "Amount",
        maxLabel: "Max:",
        processingFeeLabel: "Processing Fee",
        bridge: "Bridge",
        approve: "Approve",
      },
      nav: {
        connect: "Connect Wallet",
      },
      toast: {
        transactionSent: "Transaction sent",
        errorSendingTransaction: "Error sending transaction",
        errorDisconneting: "Could not disconnect",
      },
      switchChainModal: {
        title: "Not on the right network",
        subtitle: "Your current network is not supported. Please select one:",
      },
      connectModal: {
        title: "Connect Wallet",
      },
    },
  });

  locale.set(_locale);
}

export { _, setupI18n };

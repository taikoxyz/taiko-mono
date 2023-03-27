import { dictionary, locale } from 'svelte-i18n';
export { _ } from 'svelte-i18n';

// TODO: how about a JSON file?
export function setupI18n({ withLocale: _locale } = { withLocale: 'en' }) {
  dictionary.set({
    en: {
      home: {
        title: 'Taiko Bridge',
        selectToken: 'Select Token',
        to: 'To',
        bridge: 'Bridge',
        approve: 'Approve',
      },
      bridgeForm: {
        fieldLabel: 'Amount',
        maxLabel: 'Max',
        balance: 'Balance',
        processingFeeLabel: 'Processing Fee',
        bridge: 'Bridge',
        approve: 'Approve',
      },
      nav: {
        connect: 'Connect Wallet',
      },
      toast: {
        transactionSent: 'Transaction sent',
        errorSendingTransaction: 'Error sending transaction',
        errorDisconneting: 'Could not disconnect',
      },
      switchChainModal: {
        title: 'Not on the right network',
        subtitle: 'Your current network is not supported. Please select one:',
      },
      connectModal: {
        title: 'Connect Wallet',
      },
    },
  });

  locale.set(_locale);
}

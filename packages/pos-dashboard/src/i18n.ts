import { _, dictionary, locale } from 'svelte-i18n';

function setupI18n({ withLocale: _locale } = { withLocale: 'en' }) {
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
      transaction: {
        pending: 'Pending',
        claim: 'Claim',
        retry: 'Retry',
        release: 'Release',
        claimed: 'Claimed',
        released: 'Released',
        failed: 'Failed',
      },
      toast: {
        transactionSent: 'Transaction sent',
        transactionCompleted: 'Transaction completed!',
        errorWrongNetwork:
          'You are connected to the wrong chain in your wallet',
        errorSendingTransaction: 'Error sending transaction',
        errorDisconnecting: 'Could not disconnect',
        errorInsufficientBalance: 'Insufficient ETH balance',
        errorCheckingAllowance: 'Error checking allowance',
        fundsClaimed: 'Funds claimed successfully!',
        fundsReleased: 'Funds released successfully!',
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

export { _, setupI18n };

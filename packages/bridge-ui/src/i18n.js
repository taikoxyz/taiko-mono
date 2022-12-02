
import { _, dictionary, locale } from "svelte-i18n";

function setupI18n({ withLocale: _locale } = { withLocale: "en" }) {
    dictionary.set({
        en: {
            home: {
                title: "Taiko Bridge",
                selectToken: "Select Token",
                to: "To",
                bridge: "Bridge"
            },
            "bridgeForm": {
                fieldLabel: "Bridge Token",
                maxLabel: "Max:",
                processingFeeLabel: "Processing Fee",
            },
            nav: {
                connect: "Connect Wallet"
            },
            toast: {
                transactionSent: "Transaction sent",
                errorSendingTransaction: "Error sending transaction",
                errorDisconneting: "Could not disconnect"
            }
        }
    })

    locale.set(_locale);
}

export { _, setupI18n };

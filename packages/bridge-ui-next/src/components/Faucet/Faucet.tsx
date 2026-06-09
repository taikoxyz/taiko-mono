"use client";

import { switchChain } from "@wagmi/core";
import { useCallback, useEffect, useMemo, useState } from "react";
import {
  type Chain,
  ContractFunctionExecutionError,
  SwitchChainError,
  UserRejectedRequestError,
} from "viem";

import { chainConfig } from "$chainConfig";
import { Alert } from "@/components/Alert";
import { ActionButton } from "@/components/Button";
import { Card } from "@/components/Card";
import {
  ChainSelector,
  ChainSelectorDirection,
  ChainSelectorType,
} from "@/components/ChainSelectors";
import {
  errorToast,
  infoToast,
  successToast,
  warningToast,
} from "@/components/NotificationToast";
import { TokenDropdown } from "@/components/TokenDropdown";
import { useTranslation } from "@/i18n/useTranslation";
import { web3modal } from "@/libs/connect";
import {
  InsufficientBalanceError,
  MintError,
  TokenMintedError,
} from "@/libs/error";
import { getAlternateNetwork } from "@/libs/network";
import {
  checkMintable,
  isMintable,
  mint,
  testERC20Tokens,
  testNFT,
  type Token,
} from "@/libs/token";
import { config } from "@/libs/wagmi";
import { type Account, useAccount } from "@/stores/account";
import {
  connectedSourceChain,
  switchingNetwork,
  useConnectedSourceChain,
  useSwitchingNetwork,
} from "@/stores/network";
import { pendingTransactions } from "@/stores/pendingTransactions";

// Loosely-typed generated chainConfig narrowed to the shape we read (blockExplorers),
// matching the pattern used by the migrated ConfirmationStep/ClaimDialog components.
const chains = chainConfig as Record<
  number,
  { blockExplorers?: { default: { url: string } } }
>;

const onlyMintable = true;

/**
 * React port of `components/Faucet/Faucet.svelte`.
 *
 * The original kept a set of module-`let` flags (`minting`, `checkingMintable`,
 * `mintButtonEnabled`, `alertMessage`, `minted`, `selectedToken`, plus the
 * reactive `wrongChain` / `connected` / `disabled`) mutated imperatively from the
 * async mint / mintability flow. Each is reproduced here with `useState`; the
 * reactive `$: updateMintButtonState(...)` becomes a `useEffect`. The mint button
 * stays `disabled` while `checkingMintable || minting`, so the closures reading
 * those flags behave exactly as the Svelte handlers did.
 */
export default function Faucet() {
  const { t } = useTranslation();

  const [minting, setMinting] = useState(false);
  const [checkingMintable, setCheckingMintable] = useState(false);

  const [selectedToken, setSelectedToken] = useState<Maybe<Token>>(undefined);
  const [mintButtonEnabled, setMintButtonEnabled] = useState(false);
  const [alertMessage, setAlertMessage] = useState("");
  const [mintableTokens, setMintableTokens] = useState<Token[]>([]);
  const [minted, setMinted] = useState(false);

  // $: wrongChain = false;  (mutated inside updateMintButtonState)
  const [wrongChain, setWrongChain] = useState(false);

  // Reactive store reads.
  const $account = useAccount((s) => s);
  const $connectedSourceChain = useConnectedSourceChain();
  const $switchingNetwork = useSwitchingNetwork();

  // $: connected = isUserConnected($account);
  const connected = useMemo(() => isUserConnected($account), [$account]);

  // $: disabled = !$account || !$account.isConnected;
  const disabled = !$account || !$account.isConnected;

  const getAlertMessage = useCallback(
    (connected: boolean, reasonNotMintable: string) => {
      if (!connected) return t("messages.account.required");
      if (reasonNotMintable) return reasonNotMintable;
      return "";
    },
    [t],
  );

  // This function will check whether or not the button to mint should be
  // enabled. If it shouldn't it'll also set the reason why so we can inform
  // the user why they can't mint
  const updateMintButtonState = useCallback(
    async (connected: boolean, token?: Maybe<Token>, network?: Chain) => {
      if (!token || !network) return false;
      setCheckingMintable(true);
      setMintButtonEnabled(false);
      let reasonNotMintable = "";
      setWrongChain(false);
      try {
        await checkMintable(token, network.id);
        setMintButtonEnabled(true);
      } catch (err) {
        console.error(err);
        switch (true) {
          case err instanceof InsufficientBalanceError:
            reasonNotMintable = t("faucet.warning.insufficient_balance");
            break;
          case err instanceof TokenMintedError:
            reasonNotMintable = t("faucet.warning.token_minted");
            setMinted(true); // Set minted to true when user has already minted
            break;
          case err instanceof ContractFunctionExecutionError &&
            err.functionName === "minters":
            reasonNotMintable = t("faucet.warning.not_mintable");
            setWrongChain(true);
            break;

          default:
            reasonNotMintable = t("faucet.warning.unknown");
            break;
        }
      } finally {
        setCheckingMintable(false);
      }

      setAlertMessage(getAlertMessage(connected, reasonNotMintable));
    },
    [t, getAlertMessage],
  );

  async function mintToken() {
    // During loading state we make sure the user cannot use this function
    if (checkingMintable || minting) return;

    const srcChain = connectedSourceChain.getState();

    // Token and source chain are needed to mint
    if (!selectedToken || !srcChain) return;

    // Let's begin the minting process
    setMinting(true);
    setMintButtonEnabled(false);
    setMinted(false);

    try {
      const txHash = await mint(selectedToken, srcChain.id);

      const explorer = chains[srcChain.id]?.blockExplorers?.default.url;

      infoToast({
        title: t("faucet.mint.tx.title"),
        message: t("faucet.mint.tx.message", {
          token: selectedToken.symbol,
          url: `${explorer}/tx/${txHash}`,
        }),
      });

      await pendingTransactions.add(txHash, srcChain.id);

      successToast({
        title: t("faucet.mint.success.title"),
        message: t("faucet.mint.success.message"),
      });
      setMinted(true);
    } catch (err) {
      console.error(err);

      switch (true) {
        case err instanceof UserRejectedRequestError:
          warningToast({
            title: t("faucet.mint.rejected.title"),
            message: t("faucet.mint.rejected.message"),
          });
          break;
        case err instanceof MintError:
          // TODO: see contract for all possible errors
          errorToast({ title: t("faucet.mint.error") });
          break;
        default:
          errorToast({ title: t("faucet.mint.unknown_error") });
          break;
      }
    } finally {
      setMinting(false);
      updateMintButtonState(
        connected,
        selectedToken,
        connectedSourceChain.getState(),
      );
    }
  }

  const handleTokenSelected = (detail: { token: Token }) => {
    setSelectedToken(detail.token);
    setMinted(false);
    updateMintButtonState(
      connected,
      detail.token,
      connectedSourceChain.getState(),
    );
  };

  const switchChains = async () => {
    switchingNetwork.setState(true);
    try {
      const alternateChain = getAlternateNetwork();
      if (!alternateChain) {
        web3modal.open();
        return;
      }
      await switchChain(config, { chainId: alternateChain });
    } catch (err) {
      if (err instanceof SwitchChainError) {
        warningToast({
          title: t("messages.network.pending.title"),
          message: t("messages.network.pending.message"),
        });
      } else if (err instanceof UserRejectedRequestError) {
        warningToast({
          title: t("messages.network.rejected.title"),
          message: t("messages.network.rejected.message"),
        });
        console.error(err);
      }
    } finally {
      switchingNetwork.setState(false);
      updateMintButtonState(
        connected,
        selectedToken,
        connectedSourceChain.getState(),
      );
    }
  };

  // onMount(() => { ... mintableTokens = [...testERC20, ...testNFTs] })
  useEffect(() => {
    // Only show tokens in the dropdown that are mintable
    const testERC20 = testERC20Tokens.filter((token) => isMintable(token));
    const testNFTs = testNFT.filter((token) => isMintable(token));

    // eslint-disable-next-line react-hooks/set-state-in-effect
    setMintableTokens([...testERC20, ...testNFTs]);
  }, []);

  // $: updateMintButtonState(connected, selectedToken, $connectedSourceChain);
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    updateMintButtonState(connected, selectedToken, $connectedSourceChain);
  }, [connected, selectedToken, $connectedSourceChain, updateMintButtonState]);

  return (
    <Card
      className="w-full md:w-[524px]"
      title={t("faucet.title")}
      text={t("faucet.description")}
    >
      <div className="space-y-[35px]">
        <div className="space-y-2">
          <ChainSelector
            type={ChainSelectorType.SMALL}
            direction={ChainSelectorDirection.SOURCE}
            label={t("chain_selector.currently_on")}
            switchWallet
          />
          <TokenDropdown
            disabled={disabled}
            tokens={mintableTokens}
            onlyMintable={onlyMintable}
            value={selectedToken}
            onValueChange={(v) => setSelectedToken(v as Maybe<Token>)}
            onTokenSelected={handleTokenSelected}
          />
        </div>

        {minted ? (
          <Alert type="success">
            <span className="text-lg font-bold">
              {t("faucet.mint.success.title")}
            </span>
            <br />
            <span>{t("faucet.mint.success.message")}</span>
          </Alert>
        ) : alertMessage ? (
          <Alert type="warning" forceColumnFlow>
            {alertMessage}
          </Alert>
        ) : null}

        {wrongChain ? (
          <ActionButton
            priority="primary"
            disabled={$switchingNetwork}
            loading={$switchingNetwork}
            onClick={switchChains}
          >
            <span className="body-bold">{t("common.switch_chain")}</span>
          </ActionButton>
        ) : (
          <ActionButton
            priority="primary"
            disabled={!mintButtonEnabled || disabled || minted}
            loading={checkingMintable || minting}
            onClick={mintToken}
          >
            <span className="body-bold">
              {checkingMintable
                ? t("faucet.button.checking")
                : minting
                  ? t("faucet.button.minting")
                  : t("faucet.button.mint")}
            </span>
          </ActionButton>
        )}
      </div>
    </Card>
  );
}

function isUserConnected(user: Maybe<Account>) {
  return Boolean(user?.isConnected);
}

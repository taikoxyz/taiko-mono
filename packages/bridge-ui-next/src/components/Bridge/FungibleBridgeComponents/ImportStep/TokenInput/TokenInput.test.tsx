import { fireEvent, render, screen } from "@testing-library/react";
import { parseUnits } from "viem/utils";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { enteredAmount, selectedToken } from "@/components/Bridge/state";
import { type Token, TokenType } from "@/libs/token/types";
import { account } from "@/stores/account";

import TokenInput from "./TokenInput";

// React requires this flag for act()-wrapped renders outside its own test rig.
(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT =
  true;

// Heavy children with their own wagmi/web3modal wiring — irrelevant to the
// amount-input behavior under test.
vi.mock("@/components/Bridge/SharedBridgeComponents", () => ({
  ProcessingFee: () => null,
}));
vi.mock("@/components/TokenDropdown", () => ({
  TokenDropdown: () => null,
}));
vi.mock("@/components/OnAccount/OnAccount", () => ({
  default: () => null,
}));
vi.mock("@/i18n/useTranslation", () => ({
  useTranslation: () => ({ t: (key: string) => key }),
}));

const TEST_TOKEN = {
  name: "Test Token",
  symbol: "TST",
  addresses: { 1: "0x0000000000000000000000000000000000000001" },
  decimals: 18,
  type: TokenType.ERC20,
} as unknown as Token;

describe("TokenInput amount entry", () => {
  beforeEach(() => {
    selectedToken.setState(TEST_TOKEN);
    account.setState({
      isConnected: true,
      address: "0x0000000000000000000000000000000000000abc",
    } as never);
    enteredAmount.setState(0n);
  });

  it("commits the just-typed value to enteredAmount, not the previous render's value", () => {
    render(<TokenInput />);

    const input = screen.getByPlaceholderText("0.01");
    fireEvent.input(input, { target: { value: "100" } });

    // The Svelte original's bind:value updated `value` before on:input ran,
    // so enteredAmount always matched what the user sees. The port must not
    // lag one keystroke behind.
    expect(enteredAmount.getState()).toBe(parseUnits("100", TEST_TOKEN.decimals));
  });

  it("tracks every keystroke, not the trailing edge minus one", () => {
    render(<TokenInput />);

    const input = screen.getByPlaceholderText("0.01");
    fireEvent.input(input, { target: { value: "5" } });
    expect(enteredAmount.getState()).toBe(parseUnits("5", TEST_TOKEN.decimals));

    fireEvent.input(input, { target: { value: "55" } });
    expect(enteredAmount.getState()).toBe(
      parseUnits("55", TEST_TOKEN.decimals),
    );
  });
});

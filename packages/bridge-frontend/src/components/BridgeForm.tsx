import React from "react";
import { useContract, useNetwork, useSigner, useSwitchNetwork } from "wagmi";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { faAngleDown, faAngleUp } from "@fortawesome/free-solid-svg-icons";
import { BigNumber, constants, utils } from "ethers";

import {
  CONTRACT_ADDRESS,
  DEFAULT_FROM_CHAIN_ID,
  DEFAULT_TOKEN,
} from "../config/defaults";
import TokenVaultABI from "../assets/abi/TokenVault";

import ChainSelector from "./chainSelector";
import TokenSelector from "./tokenSelector";
import { Token } from "../types";

const BridgeForm: React.FC<{}> = () => {
  const { chain } = useNetwork();
  const [fromChainId, setFromChainId] = React.useState(
    chain?.id ?? DEFAULT_FROM_CHAIN_ID
  );

  const { data: signer } = useSigner();

  const contract = useContract({
    addressOrName: CONTRACT_ADDRESS[fromChainId].tokenVault,
    contractInterface: TokenVaultABI,
    signerOrProvider: signer,
  });

  const [openAdvanced, setOpenAdvanced] = React.useState<boolean>(false);

  const { isLoading, switchNetwork } = useSwitchNetwork({
    chainId: fromChainId,
  });
  const [showSwitchButton, setShowSwitchButton] =
    React.useState<boolean>(false);

  const [token, setToken] = React.useState<Token>(DEFAULT_TOKEN);

  React.useEffect(() => {
    if (chain?.id !== fromChainId) {
      setShowSwitchButton(true);
    } else {
      setShowSwitchButton(false);
    }
  }, [chain, fromChainId]);

  const chainChangeHandler = (name: string, chainId: number) => {
    if (name === "from") {
      setFromChainId(chainId);
    }
  };

  const switchNetworkHandler = async () => {
    switchNetwork && (await switchNetwork());
    setShowSwitchButton(false);
  };

  const onTokenSelected = (token: Token) => {
    setToken(token);
  };

  const submitHandler = async (event: React.SyntheticEvent) => {
    event.preventDefault();
    const { from, to, tokenValue, token, memo } = event.target as any;

    const owner = await signer?.getAddress();

    const message = {
      sender: owner,
      srcChainId: from.value,
      destChainId: to.value,
      owner: owner,
      to: constants.AddressZero,
      refundAddress: owner,
      depositValue: tokenValue.value,
      callValue: 0,
      processingFee: 0,
      gasLimit: 10000,
      memo: memo.value,
    };

    const expectedAmount = BigNumber.from(
      utils.parseUnits(message.depositValue, token.decimals)
    )
      .add(message.callValue)
      .add(message.processingFee);

    const tx = await contract.sendEther(
      message.destChainId,
      owner,
      message.gasLimit,
      message.processingFee,
      message.refundAddress,
      message.memo,
      {
        value: expectedAmount,
      }
    );

    await tx.wait();
  };

  return (
    <form
      className="bg-white rounded-md p-4 flex flex-col w-5/6 md:w-1/3"
      onSubmit={submitHandler}
    >
      <ChainSelector.Select
        className="flex items-center justify-between"
        onChainChange={chainChangeHandler}
        defaultFromChain={fromChainId}
      >
        <div>
          <span>From:</span>
          <div className="text-xl">
            <ChainSelector.Options name="from" />
          </div>
        </div>
        <ChainSelector.Swap />
        <div>
          <span>To:</span>
          <div className="text-xl">
            <ChainSelector.Options name="to" />
          </div>
        </div>
      </ChainSelector.Select>
      <div className="flex items-center justify-between mt-8 flex-col lg:flex-row">
        <TokenSelector
          filterByChainId={fromChainId}
          onTokenSelected={onTokenSelected}
        />
        <input
          type="text"
          name="token"
          className="hidden"
          readOnly
          value={token?.address}
        />
        <input
          type="number"
          step={Math.pow(10, -token.decimals)}
          name="tokenValue"
          placeholder="0.0"
          className="border-none bg-none text-right p-2"
        />
      </div>
      {showSwitchButton && switchNetwork && (
        <button
          onClick={switchNetworkHandler}
          type="button"
          className="bg-taiko-pink text-white w-[140px] m-auto rounded-md py-2 mt-6"
          disabled={isLoading}
        >
          {isLoading ? "Switching..." : "Switch Network"}
        </button>
      )}
      <fieldset className="my-4 flex items-center justify-center border-t overflow-hidden">
        <legend
          className="text-center px-3 cursor-pointer"
          onClick={() => setOpenAdvanced((val) => !val)}
        >
          Advanced{" "}
          <FontAwesomeIcon
            icon={openAdvanced ? faAngleUp : faAngleDown}
            size="sm"
          />
        </legend>
        <div
          className={`px-2 flex flex-col w-full justify-center transition-all duration-300  ${
            openAdvanced ? "py-2 h-content" : "h-0"
          }`}
        >
          <label htmlFor="data">Memo</label>
          <input
            id="memo"
            name="memo"
            placeholder="Enter memo"
            className="border bg-none p-2 my-1 w-full rounded-md"
          />
        </div>
      </fieldset>
      <button
        type="submit"
        className={`bg-taiko-pink text-white w-[100px] m-auto rounded-md py-2 mt-6 ${
          !(showSwitchButton && switchNetwork) ? "" : "hidden"
        }`}
      >
        Bridge
      </button>
    </form>
  );
};

export default BridgeForm;

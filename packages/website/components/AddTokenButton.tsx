import { eldfellChainConfig, grimsvotnChainConfig } from "../constants/chains";

type AddTokenButtonProps = {
  network: "Eldfell" | "Grimsvotn" | "Sepolia";
  token: "TTKO" | "BLL" | "HORSE";
};



const chainMap = {
  Eldfell: "0x28c5d", // 167005
  Grimsvotn: "0x28c5d", // 167005
  Sepolia: "0xaa36a7", // 11155111
};


const tokenMap = {
  Sepolia: {
    TTKO: "0xE52952B8063d0AE6Bd35E894866d8148976ce645", // 167005
    BLL: "0x39e12053803898211F21047D56017986E0f070c1", // 167005
    HORSE: "0x958b482c4E9479a600bFFfDDfe94D974951Ca3c7", // 11155111
  },
  Grimsvotn: {
    TTKO: "0x7b1a3117B2b9BE3a3C31e5a097c7F890199666aC", // 167005
    BLL: "0x6302744962a0578E814c675B40909e64D9966B0d", // 167005
    HORSE: "0xa4505BB7AA37c2B68CfBC92105D10100220748EB", // 11155111
  }
};

const imageMap = {
  TTKO: "https://raw.githubusercontent.com/taikoxyz/taiko-mono/main/packages/branding/testnet-token-images/ttko.svg",
  BLL: "https://raw.githubusercontent.com/taikoxyz/taiko-mono/main/packages/branding/testnet-token-images/bull_32x32.svg",
  HORSE: "https://raw.githubusercontent.com/taikoxyz/taiko-mono/main/packages/branding/testnet-token-images/horse.svg",
}

async function AddToken(network: AddTokenButtonProps["network"], token: AddTokenButtonProps["token"]) {
  if (!(window as any).ethereum) {
    alert("Metamask not detected! Install Metamask then try again.");
  }

  const tokenAddress = tokenMap[network][token];
  const tokenSymbol = token;
  const tokenDecimals = token === "TTKO" ? 8 : 18;
  //   const tokenImage = 'http://placekitten.com/200/300';

  if ((window as any).ethereum.chainId != chainMap[network]) {
    await (window as any).ethereum.request({
      method: "wallet_switchEthereumChain",
      params: [
        {
          chainId: chainMap[network],
        },
      ],
    });
  }

  try {
    await (window as any).ethereum.request({
      method: 'wallet_watchAsset',
      params: {
        type: 'ERC20', // Initially only supports ERC-20 tokens, but eventually more!
        options: {
          address: tokenAddress, // The address of the token.
          symbol: tokenSymbol, // A ticker symbol or shorthand, up to 5 characters.
          decimals: tokenDecimals, // The number of decimals in the token.
          image: imageMap[token], // A string url of the token logo
        },
      },
    });
  } catch (error) {
    alert(
      "Failed to add the token with wallet_watchAsset request." +
      error.message
    );
  }
}

export default function AddTokenButton(props: AddTokenButtonProps) {
  return (
    <div
      onClick={() => AddToken(props.network, props.token)}
      className="hover:cursor-pointer text-neutral-100 bg-[#E81899] hover:bg-[#d1168a] border-solid border-neutral-200 focus:ring-4 focus:outline-none focus:ring-neutral-100 font-medium rounded-lg text-sm px-3 py-2 text-center inline-flex items-center"
    >
      Add {props.token} ({props.network})
    </div>
  );
}

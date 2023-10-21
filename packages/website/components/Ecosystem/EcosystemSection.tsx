import { EcosystemCard } from "./EcosystemCard";
import { useState } from "react";

type Category =
  | "all"
  | "bridge"
  | "dashboard"
  | "defi"
  | "explorer"
  | "gaming"
  | "nft"
  | "oracle"
  | "wallet"
  | "zk";

interface EcosystemData {
  icon: string;
  name: string;
  link: string;
  description: string;
  filters: Category[];
  isLive: boolean;
}

const ecosystemData: EcosystemData[] = [
  {
    icon: "/images/ecosystem/ait.png",
    name: "AIT Protocol",
    link: "https://ait.tech/",
    description:
      "AIT Protocol is the first’s Web3 data infrastructure focusing on AI data annotations, leverages blockchain technology to deliver a trustless and cross-border labor market being strategically incentivized by crypto economics and having instant cross-nation payment settlements.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/alphamint.png",
    name: "Alphamint",
    link: "https://www.alphamint.online/",
    description:
      "Multichain NFT marketplace to create, sell and buy ERC-721 tokens.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/bitget.png",
    name: "Bitget Wallet",
    link: "https://web3.bitget.com/",
    description: "Faster trading with your Web3 trading wallet of the future.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/blockscout.svg",
    name: "Blockscout",
    link: "https://blockscout.com",
    description: "Blockchain Explorer for inspecting and analyzing EVM Chains.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/brian.png",
    name: "Brian",
    link: "https://www.brianknows.org",
    description:
      "Brian is a collection of AI models, trained on web3-related data, that allows everyone to learn and interact with the decentralized world by prompting.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/covalent.png",
    name: "Covalent",
    link: "https://www.covalenthq.com/",
    description:
      "Covalent's industry-leading Unified API brings visibility to billions of data points across 200+ blockchains for developers building multi-chain applications.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/taiko.svg",
    name: "Bridge",
    link: "https://bridge.jolnir.taiko.xyz",
    description: "Bridge is a dapp that lets you bridge tokens with Taiko.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/catalyst.png",
    name: "Catalyst",
    link: "https://catalyst.exchange/",
    description: "Catalyst is the cross-chain AMM built to connect all chains",
    filters: [],
    isLive: false,
  },
  {
    icon: "/images/ecosystem/chaindrop-faucet.png",
    name: "Chaindrop Faucet",
    link: "https://chaindrop.org",
    description:
      "ChainDrop offers an effortless way to access Web3 test tokens. With just one click, you can receive free Web3 test tokens directly into your wallet.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/chainpray.png",
    name: "ChainPray",
    link: "https://chainpray.com",
    description:
      "ChainPray provides spiritual assistance to ordinary users in the cryptocurrency community, combining traditional prayer with blockchain technology.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/cloak.png",
    name: "Cloak",
    link: "https://cloak.exchange/",
    description:
      "Cloak is a non-custodial dark pool, offering trustless, MEV-resistant, and slippage-resistant trades for any ERC-20 trading pairs.",
    filters: [],
    isLive: false,
  },
  {
    icon: "/images/ecosystem/crypton.png",
    name: "Crypton",
    link: "https://crypton.xyz",
    description:
      "Help to understand crypto projects by providing the necessary tools to increase your productivity and time.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/cyberscan.png",
    name: "Cyberscan",
    link: "https://www.cyberscope.io/cyberscan",
    description:
      "Cyberscan is a convenient tool that helps investors quickly gain insight into a given cryptocurrency token",
    filters: [],
    isLive: false,
  },
  {
    icon: "/images/ecosystem/foxwallet.png",
    name: "FoxWallet",
    link: "https://foxwallet.com",
    description:
      "FoxWallet is a safe and easy-to-use decentralized audited wallet, dedicated to creating an entrance and connection to the Web3 world.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/gourds.jpeg",
    name: "Gourds",
    link: "https://gourds.studio",
    description:
      "Gourds aims to achieve crypto market efficiency by introducing novel trading instruments for mass adoption.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/izar.png",
    name: "IZAR",
    link: "https://izar.xyz/",
    description:
      "IZAR is a privacy-preserving interoperability protocol between Ethereum and Aleo ecosystem, harnessing the power of zero-knowledge cryptography to protect user privacy and security.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/metamerge.png",
    name: "Meta Merge",
    link: "https://taiko-match3.metamerge.xyz/",
    description:
      "Meta Merge (@MetaMerge_xyz) is a distinctive GameFi metaverse nurtured by Ultiverse (@UltiverseDAO), delivers ground-breaking gameplay and charming pets, thereby enriching the Web3 gaming ecosystem.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/mesprotocol.png",
    name: "MES Protocol",
    link: "https://www.mesprotocol.com/",
    description: "MES is a cross-rollup orderbook DEX.",
    filters: [],
    isLive: false,
  },
  {
    icon: "/images/ecosystem/mintpad.jpeg",
    name: "Mintpad",
    link: "https://mintpad.co/",
    description:
      "Mintpad is a multi-chain, no-code creator tool solution designed to assist creators in implementing artwork, passes, tickets, and other items on various EVM-compatible blockchain networks.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/goneuron.jpeg",
    name: "neuron 🧠",
    link: "https://goneuron.xyz/",
    description:
      "neuron is a blazing fast privacy focused cross-chain bridge for transferring Ethereum native assets quickly and privately between chains faster than L1 native bridges cheaply.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/kalkiswap.png",
    name: "KALKI SWAP",
    link: "https://kalkiswap.org",
    description:
      "KalkiSwap is a cutting-edge decentralized exchange (DEX) that provides lightning-fast token swapping and innovative liquidity provision across diverse blockchains.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/kekkai.png",
    name: "KEKKAI",
    link: "https://kekkai.io",
    description:
      "KEKKAI is a product that protects the security of web3 user assets. It can help users get the result of asset flow in advance and analyze its risks when interacting with wallets.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/loopring.svg",
    name: "Loopring Wallet",
    link: "https://wallet.loopring.io",
    description:
      "Loopring is your mobile gateway to Ethereum L2, enabling you to easily trade, swap, collect, stake, and invest without the costly gas fees.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/morkie.png",
    name: "Morkie",
    link: "https://www.morkie.xyz/",
    description:
      "Morkie aims to create an immersive oasis for NFT enthusiasts and collectors, offering them a unique space to not only showcase their digital assets but also to earn rewards for their loyalty and participation in the ecosystem.",
    filters: ["nft"],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/movechess.png",
    name: "Movechess",
    link: "https://movechess.com",
    description:
      "MoveChess is a chess project currently under development by the MoveLabs team. Its primary goal is to provide a platform for chess enthusiasts within the Taiko community and offer various activities related to NFT rewards on the MoveChess platform.",
    filters: [],
    isLive: false,
  },
  {
    icon: "/images/ecosystem/mxc.svg",
    name: "MXC",
    link: "https://doc.mxc.com/",
    description:
      "Layer3 IoT app chain built using Taiko's open source software.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/nfts2me.jpg",
    name: "NFTs2Me",
    link: "https://nfts2me.com/app",
    description:
      "NFTs2Me is a multichain user-friendly comprehensive platform to create, deploy and manage your NFT collection and community, 100% free with advanced functionalities.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/omnikingdoms.png",
    name: "OmniKingdoms",
    link: "https://omnikingdoms.io",
    description:
      "MMORPG focused on state transitions and asset evolution. Train and level up in order to quest, craft and battle!",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/omnisea.png",
    name: "Omnisea",
    link: "https://www.omnisea.org",
    description:
      "Omnisea is the first permissionless Omnichain NFT Launchpad and Bridge powered by LayerZero.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/orally.png",
    name: "Orally",
    link: "https://orally.network",
    description:
      "The fully on-chain oracles for secure and reliable decentralized data feeding and automation across multiple chains.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/orbiter.jpg",
    name: "Orbiter",
    link: "https://orbiter.finance",
    description:
      "A decentralized cross-rollup Layer 2 bridge with a contract only on the destination side.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/owlto.png",
    name: "Owlto",
    link: "https://owlto.finance",
    description: "The decentralized cross-rollup bridge focused on Layer2.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/particle-network.png",
    name: "Particle Network",
    link: "https://particle.network/",
    description: "The full-stack infrastructure to simplify Web3.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/phalcon-explorer.png",
    name: "Phalcon Explorer",
    link: "https://explorer.phalcon.xyz/",
    description:
      "Designed specifically for the DeFi community, Phalcon Explorer empowers developers, traders, and security researchers to delve deep into transactions.",
    filters: [],
    isLive: false,
  },
  {
    icon: "/images/ecosystem/pheasant-network.png",
    name: "Pheasant Network",
    link: "https://pheasant.network",
    description:
      "Pheasant Network is an optimistic bridge between Layer 1 and Layer 2.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/pixelswap.png",
    name: "PixelSwap",
    link: "https://pixelswap.xyz",
    description:
      "Pixelswap: Pioneering the Future of Decentralized Exchange with Seamless Multichain Support and Enhanced User Experience.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/pizzap.png",
    name: "Pizzap",
    link: "https://taiko.pizzap.io",
    description:
      "Pizzap is a user-benefit-oriented and mass-adopted AI ecosystem. Members can create, show and trade NFTs in this community on Taiko.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/polyhedra.svg",
    name: "Polyhedra",
    link: "https://polyhedra.network/",
    description:
      "Polyhedra Network is building the infrastructure for Web3 interoperability with efficient zero-knowledge proof protocols. Polyhedra Network designs and implements zkBridge, providing trustless and efficient cross-chain infrastructures for layer-1 and layer-2 interoperability.",
    filters: ["zk"],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/rai-finance.png",
    name: "RAI Finance",
    link: "https://app.rai.finance/#/aggregateSwap",
    description:
      "User can easily compare and swap multiple chains on top of the Taiko blockchain. A service that links multiple swaps and organizes multiple tokens.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/rubic.png",
    name: "Rubic",
    link: "https://rubic.exchange/",
    description:
      "Rubic enhances interoperability through network bridging and cross-chain dev tools for omnichain dApps. Users access diverse assets via varied DEXs under a unified interface with optimized cross-chain transactions.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/rubydex.png",
    name: "RubyDex",
    link: "https://testnet.rubydex.com/en",
    description:
      "Perpetuals DEX offering crypto and traditional assets like Forex, Commodities, Stocks, ETFs, NFT perps, and more.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/stakeme.png",
    name: "STAKEME",
    link: "https://stakeme.pro/",
    description:
      "STAKEME assists web 3.0 projects with product testing, increasing testnet participants, and offers optimal development tools. As reliable validators, we offer RPC, snapshots, and essential utilities. We have developed a multi-chain faucet and a self-writing explorer adapted to high loads.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/soul-wallet.svg",
    name: "Soul Wallet",
    link: "https://soulwallet.io",
    description:
      "The next-generation smart contract wallet powered by ERC-4337. Simply set up in seconds without recovery phrase.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/superscalar.png",
    name: "SuperScalar",
    link: "https://www.superscalar.io/",
    description:
      "Superscalar specializes in cutting-edge computing acceleration solutions, with a focus on zero-knowledge proof algorithm optimization, FPGA development, and ASIC design.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/surfer-monkey.png",
    name: "SurferMonkey",
    link: "https://www.surfermonkey.io",
    description: "DarkWeb3.0: Anonymous on chain-tx and interoperability.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/taiko.svg",
    name: "Swap v2",
    link: "https://swap.jolnir.taiko.xyz",
    description:
      "Swap v2 is a dapp that lets you swap tokens on Taiko (fork of Uniswap v2).",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/taiko.svg",
    name: "Swap v3",
    link: "https://swap-v3.jolnir.taiko.xyz",
    description:
      "Swap v3 is a dapp that lets you swap tokens on Taiko (fork of Uniswap v3).",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/taiko-dashboard.png",
    name: "Taiko Node Dashboard",
    link: "https://github.com/wolfderechter/taiko-node-dashboard-docker",
    description:
      "A user friendly, easy to read, and visually pleasing dashboard for those running a Node/Proposer/Prover.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/taikoverse.png",
    name: "Taikoverse",
    link: "https://linktr.ee/taikoverse",
    description: "An infinite and unstoppable world running on Taiko's stack.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/thirdweb.png",
    name: "thirdweb",
    link: "https://thirdweb.com",
    description:
      "thirdweb is a complete web3 development framework that provides everything you need to connect your apps and games to decentralized networks.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/vooi.jpeg",
    name: "Vooi",
    link: "https://vooi.io/",
    description:
      "vooi is a stableswap AMM DEX built for L2 chains on top of Unbounded pool technology.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/x7finance.png",
    name: "X7R",
    link: "https://x7.finance/",
    description:
      "Launch your project on Xchange with 10-1000x the initial liquidity into the Ethereum ecosystem where anyone can Swap, Borrow and Lend.",
    filters: [],
    isLive: false,
  },
  {
    icon: "/images/ecosystem/xverse.png",
    name: "Xverse",
    link: "https://taiko-test.xverse.fi/?chain=taiko_testnet",
    description:
      "Stablecoin Project, using Uniswap V3 LP token. With CDP mechanism, LP NFT of stable coin pair will become collateral of our Stable coin.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/zeroswap.png",
    name: "ZeroSwap",
    link: "https://testdrive.zeroswap.io/",
    description:
      "Build, Launch and Swap, with No Fee and Gas-Less Transactions.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/zkpool.png",
    name: "ZKPool",
    link: "https://zkpool.io",
    description:
      "ZKPool aggregates the computing power of accelerators for zero-knowledge proofs and provides services to ZKP applications.",
    filters: ["zk"],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/zkdelx.jpg",
    name: "zkDELX",
    link: "https://zkdelx-front.vercel.app",
    description:
      "zkDELX is a decentralized electricity exchange market based on zkEVM to facilitate the electrical vehicles and renewable energy industries.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/zklink.png",
    name: "zkLink",
    link: "https://zk.link",
    description:
      "A ZK-Rollup trading infrastructure empowering DeFi, RWA, and NFT super dApps in a rollup-centric, multi-chain world.",
    filters: [],
    isLive: true,
  },
  {
    icon: "/images/ecosystem/zksynth.png",
    name: "ZKSynth",
    link: "https://app.zksynth.com/",
    description:
      "zkSynth allows you to create and trade synthetic assets that track the price of any real-world asset, such as stocks, commodities, currencies, and more.",
    filters: [],
    isLive: false,
  },
];

export function EcosystemSection() {
  // NOTE: commented out because we won't need this until we have grown our ecosystem page further
  const [activeFilter, setActiveFilter] = useState<Category>("all");

  const filteredData =
    activeFilter === "all"
      ? ecosystemData
      : ecosystemData.filter((data) => data.filters.includes(activeFilter));

  return (
    <>
      {/* NOTE: commented out because we won't need this until we have grown our ecosystem page further */}
      {/* <br/>
      <div className="flex justify-center space-x-4 mb-8">
        <FilterLabel
          text="all"
          activeFilter={activeFilter}
          setActiveFilter={setActiveFilter}
        />
        <FilterLabel
          text="bridge"
          activeFilter={activeFilter}
          setActiveFilter={setActiveFilter}
        />
        <FilterLabel
          text="dashboard"
          activeFilter={activeFilter}
          setActiveFilter={setActiveFilter}
        />
        <FilterLabel
          text="defi"
          activeFilter={activeFilter}
          setActiveFilter={setActiveFilter}
        />
        <FilterLabel
          text="explorer"
          activeFilter={activeFilter}
          setActiveFilter={setActiveFilter}
        />
        <FilterLabel
          text="gaming"
          activeFilter={activeFilter}
          setActiveFilter={setActiveFilter}
        />
        <FilterLabel
          text="nft"
          activeFilter={activeFilter}
          setActiveFilter={setActiveFilter}
        />
        <FilterLabel
          text="oracle"
          activeFilter={activeFilter}
          setActiveFilter={setActiveFilter}
        />
        <FilterLabel
          text="wallet"
          activeFilter={activeFilter}
          setActiveFilter={setActiveFilter}
        />
        <FilterLabel
          text="zk"
          activeFilter={activeFilter}
          setActiveFilter={setActiveFilter}
        />
      </div> */}
      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-6 pt-6">
        {/* NOTE: commented out because we won't need this until we have grown our ecosystem page further */}
        {filteredData.map((_) => (
          // {ecosystemData.map((_) => (
          <EcosystemCard
            key={_.name}
            icon={_.icon}
            name={_.name}
            isLive={_.isLive}
            link={_.link}
            description={_.description}
          />
        ))}
      </div>
    </>
  );
}

// NOTE: commented out because we won't need this until we have grown our ecosystem page further
function FilterLabel({ text, activeFilter, setActiveFilter }) {
  const isActive = activeFilter === text;

  const buttonStyles = `border rounded-full py-1 px-4 text-sm focus:outline-none transition-colors duration-200 font-bold ${
    isActive
      ? "bg-gray-300 text-black"
      : "bg-white text-gray-700 dark:bg-black dark:text-gray-300"
  } ${
    isActive
      ? "hover:bg-gray-400"
      : "hover:bg-neutral-100 dark:hover:bg-neutral-800"
  }`;

  return (
    <button className={buttonStyles} onClick={() => setActiveFilter(text)}>
      {text === "all" ? "all" : text}
    </button>
  );
}

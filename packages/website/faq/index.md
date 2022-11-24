# Frequently Asked Questions

## What is Taiko?

Taiko is a decentralized Ethereum-equivalent ZK-EVM and general-purpose ZK-Rollup. Its purpose is to allow developers and users of dApps developed for Ethereum L1 to be used on Taiko without any changes. As a result, dApps can be easily deployed to L2, inheriting Ethereum's security while incurring lower transaction fees than on L1.

## How does Taiko differ from other ZK-EVMs?

Currently, only the Privacy and Scaling Explorations (PSE) team and Taiko are working on a Type 1 ZK-EVM. This means it aims to be Ethereum-equivalent.

You can read more about the difference between a Type 1 ZK-EVM and others from our blog post, [The Type 1 ZK-EVM](https://mirror.xyz/labs.taiko.eth/w7NSKDeKfJoEy0p89I9feixKfdK-20JgWF9HZzxfeBo).

## Where can I learn more about Taiko?

Here are the official links to our social media and public documentation:

- Website: https://taiko.xyz/
- Twitter: https://twitter.com/taikoxyz
- Reddit: https://www.reddit.com/r/taiko_xyz/
- Blog: https://mirror.xyz/labs.taiko.eth
- GitHub: https://github.com/taikoxyz/
- Whitepaper: https://github.com/taikoxyz/whitepaper

## What is Layer 2 (L2)?

Although security and decentralization are built into Ethereum L1, its popularity has led to spikes in network traffic and data congestion. Gas prices go up as a result, and apps run more slowly.

L2 refers to an off-chain solution built on top of Ethereum L1 that aids in the reduction of data bottlenecks and improves scaling. L2 differentiates itself by offering lower fees and higher throughput. L2 transactions combine multiple off-chain transactions into a single L1 transaction, reducing data load while also maintaining security and decentralization by settling transactions on the mainnet.

[Learn more about Layer 2](https://ethereum.org/en/layer-2/)

## What is a rollup?

Rollups conduct transactions on L2, which is quicker and allows for batching, and then send the transaction data back to Ethereum L1 at a far cheaper cost. Users can benefit from the rollup's efficiency and accessibility as well as the safety of the Ethereum blockchain as a result. Rollups are a fundamental piece to Ethereum's scaling solution.

[Learn more about scaling](https://ethereum.org/en/developers/docs/scaling/)

## What is a ZK-Rollup?

ZK-Rollups generate cryptographic proofs to validate transaction authenticity. These proofs which are posted to L1 are known as validity proofs. ZK-Rollups are more efficient because they maintain the state of all L2 transfers, which are only updated via validity proofs. There are 2 types of validity proof: SNARKs (short non-interactive argument of knowledge), and STARKs (scalable transparent argument of knowledge).

Every batch, which can have thousands of transactions submitted to Ethereum, includes a cryptographic proof with minimal data verified by a contract that is deployed on the Ethereum mainnet. Since ZK-Rollups do not require the entire transaction data, it is simpler to validate blocks and transfer data to L1.

[Learn more about ZK-Rollups](https://ethereum.org/en/developers/docs/scaling/zk-rollups/)

## What is an EVM?

Developers utilize an Ethereum virtual machine, often known as a "virtual computer," as a software platform to build decentralized applications (dApps) and to run and deploy smart contracts on the Ethereum network. All Ethereum accounts and smart contracts exist on this virtual machine. The EVM's purpose is to determine what the overall state of Ethereum for each block in the blockchain will be.

[Learn more about the EVM](https://ethereum.org/en/developers/docs/evm/)

## What is a ZK-EVM?

The ZK-EVM proves the correctness of the EVM computations on the rollup with validity proofs.

Taiko implements a ZK-EVM that supports every EVM opcode, producing a validity proof of the ZK-EVM circuit. Besides perfect compatibility with Ethereum L1 smart contracts and dapps, this also means that all Ethereum and solidity tooling works seamlessly with Taiko, no need to disrupt developers’ workflow whatsoever.

## What are Zero-Knowledge Proofs (ZKPs)?

A zero-knowledge proof is a method by which one party (the prover) can prove to another party (the verifier) that something is true, without revealing any information apart from the fact that this specific statement is true.

There are 2 types of zero-knowledge proofs: ZK-SNARKs and ZK-STARKs. Taiko uses ZK-SNARKs in its design.

## What Taiko means?

It comes from a Chinese old saying  一鼓作气 (Yīgǔzuòqì) meaning "Do it all at once". 

The first drum beat cheers people up, the second weakens them, and the third devitalizes them, the first is the most powerful.
Taiko is the "drum".


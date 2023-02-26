# How to contribute to this

This glossary is meant to be for rollups at large; it's not tied to any specific rollup project or implementation. That said, if there is ambiguity in a definition, it can be assumed that the concept pertains to rollups built atop Ethereum. Further, some concepts apply to Ethereum/L1 as well as rollups (L2); the glossary tries not to define the concept in relation to Ethereum/L1. For Ethereum definitions, check out the [Ethereum glossary](https://ethereum.org/en/glossary/).

There is a 500 character limit. And it should be alphanumerical. A definition should be of this format:

```
## <name>
<description capped at 500 characters>
```

## Application-specific rollup

A [rollup](#rollup) that supports only a certain type of application or functionality. For example, a rollup that supports only ETH and ERC20 token transfers, or DEX swaps. This is in contrast to [general-purpose rollups](#general-purpose-rollup) which support arbitrary computations.

## Arithmetic circuit

The computation model of zkSNARKs.

## Blobs

The data that a rollup publishes to its [L1](#layer-1)/[data availability (DA)](#data-availability) layer. They consist of the [L2](#layer-2) transactions that are rolled up, along with some metadata. Blobs are introduced as a new transaction type within Ethereum with [EIP-4844](#Proto-danksharding-(EIP-4844)), and has rollup scaling specifically in mind. Blobs persist on Ethereum’s Beacon Chain ephemerally.

## Blobspace

The storage area within Ethereum’s Beacon nodes where [blobs](#blobs) are published by rollups and ephemerally stored.

## Block

An ordered list of transactions and chain-related metadata that gets bundled together and published to the L1/DA layer. [Nodes](#node) execute the transactions contained within blocks to change the rollup chain’s state. Protocol rules dictate what constitutes a valid block, and invalid blocks are skipped over.

## Bridge

A message-passing protocol between two blockchains (between L1 and L2, and between L2s). At its most basic, a bridge consists of a smart contract which can escrow funds on one side of the bridge, and instruct the release or minting of corresponding assets on the other side. How these instructions are validated is a critical factor in assessing the trust assumptions of a bridge.

## Bytecode

Generally, an instruction set designed for efficient execution by a software interpreter or a virtual machine. Unlike human-readable source code, bytecode is expressed numerically. Within the context of rollups, often related to whether the bytecode of programs on the rollup are capable of being run as-is on Ethereum as well, and vice versa.

## Challenge period

In [optimistic rollups](#optimistic-rollup), the window of time wherein network participants can assert that some fraud was included in a prior block. Most optimistic rollups currently specify a challenge window of 7 days. By extending the period, there is more time for participants to guard against fraud (invalid state transitions), but also more time until [finality](#finality) is reached.

## Circuit

A program written for the purposes of being proven within a proving system. A circuit is a mathematical representation of the computation to be executed, and is therefore sometimes referred to as an arithmetic circuit. Circuits can be written in different languages, ranging from low-level to high-level.

## Client

Sometimes labelled interchangeably as a “[node](#node)”, they are tasked with processing transactions and managing the rollup’s state. They run the computations for each transaction according to the rollup’s virtual machine and protocol rules. If comparing to Ethereum clients, these would be execution clients such as Geth, as opposed to consensus clients.

## Consensus

An agreement on the latest and correct state of a blockchain. Unlike [L1](#layer-1) blockchains which coordinate participating nodes with consensus rules, [rollups](#rollup) rely on L1s for reaching consensus by checking the state of the rollup smart contract deployed thereon.

## Compatibility

The degree to which a rollup can make use of existing patterns, code, and tooling from another blockchain or development environment. Today, this typically refers to how well rollups and developers thereon can make use of the [Ethereum Virtual Machine](#Ethereum-Virtual-Machine-(EVM)), existing smart contracts, and other Ethereum infrastructure.

## Commitment Scheme

A cryptographic primitive that (i) allows one (usually a [prover](#prover)) to commit to a chosen statement and send this commitment to the [verifier](#verifier) while keeping it hidden to others, (ii) and allows verifier to check the commitment and accept or reject it.
The commitment scheme should satisfy two properties: (i) it should be binding that is once the prover has committed she is bound to the message she has committed, (ii) it should be hiding that is the commitment reveals nothing new about the message to the verifier.

## Completeness

One of three properties of [zero-knowledge proofs](#zero-knowledge-proof), completeness states that if a statement is true, an honest [verifier](#verifier) will be convinced of this by an honest [prover](#prover).

## Danksharding

A sharding design proposed for Ethereum. Instead of providing more space for transactions, Ethereum sharding provides more space for [blobs](#blobs) of data. Verifying a blob simply requires checking that the blob is available - that it can be downloaded from the network. The data space in these blobs is expected to be used by layer-2 rollup protocols.
In comparison to other sharding mechanisms, where there are a fixed number of shards with distinct blocks and distinct block proposers, in Danksharding there is only one proposer that chooses all transactions and all data that go into that slot.

## Data availability

The property of a rollup’s state being reachable by any node retrieving the inputs that were rolled up and executed to reach said state. Data availability (DA) is the preeminent notion which allows a rollup to scale securely. A rollup is faced with a decision of what to use as a DA layer (data storage) to guarantee that any node can retrieve this data, permissionlessly, under any circumstance. For this reason, using Ethereum for DA currently provides the strongest security guarantees.

## Decentralization

The concept of moving the control and execution of processes away from a central entity. In the context of rollups, there are several factors which separately can be more or less decentralized, leading to the degree to which the rollup as a whole is uncapturable by a central entity. The most significant factors include who can run a node, who can propose rollup blocks, who can prove blocks (in ZKRs), and who can [upgrade](#Upgradeability) the rollup smart contracts.

## Deterministic

The concept of some function or process having a single outcome that is knowable by all participants. In the context of a rollup, it generally refers to the new state being calculable given a prior state and a list of transactions to be executed.

## Ethereum Virtual Machine (EVM)

A stack-based virtual machine that executes [bytecode](#bytecode). In Ethereum, the execution model specifies how the system state is altered given a series of bytecode instructions and a small tuple of environmental data. In the context of rollups, the EVM is a choice of execution environment that rollups could implement, as in the case of EVM ZK-Rollups ([ZK-EVMs](#ZK-EVM)) and EVM [optimistic rollups](#optimistic-rollup).

## Execution environment

Refers to both the environment where transactions are processed, constituted by the execution [clients](#client), as well as the virtual machine model which the clients run.

## Equivalence

A perfect degree of [compatibility](#compatibility); where one system or concept is indistinguishable from another in the domain being compared. In the context of rollups, it generally refers to the proximity to the [EVM](#Ethereum-Virtual-Machine-(EVM)) and to Ethereum architecture.

## Escape hatch

The facility for any user of a rollup to exit the system with their assets under any circumstance. Most relevant in rollups with a centralized [proposer](#proposer), wherein users do not have the ability to propose blocks, but can nonetheless exit the rollup by interacting with a smart contract on L1.

## Finality

The guarantee that a set of transactions before a given time will not change and can't be reverted. When finality is reached differs meaningfully between ZK (validity) and optimistic rollups.

## Fast Fourier transform (FFT)

An algorithm that computes the Discrete Fourier Transform (DFT) of a sequence in a more efficient manner, that is taking O(n*log(n)) instead of O(n*n). It is used for extremely fast multiplication of large numbers, multiplication of polynomials, and extremely fast generation and recovery of erasure codes.

## Fraud proof

Also referred to as a fault proof, it is the construction of an assertion that fraud was perpetrated on an optimistic rollup. More concretely, that an invalid state transition took place according to the protocol rules. The submitter of a fraud proof would expect a reward from the optimistic rollup protocol for helping maintain the integrity of the system.

## FRI

A proximity test method that is used to determine whether a set of points is mostly on a polynomial with a degree less than a specified value. It resembles the FFT but the arithmetic complexity of its prover is strictly linear and that of the verifier is strictly logarithmic.

## Gas limit

The maximum amount of gas a transaction or block may consume.

## Gas price

Price in ether of one unit of gas specified in a transaction.

## General-purpose rollup

A rollup that supports arbitrary computations and all applications and functionalities that are available on the corresponding Layer 1.

## Geth (Go Ethereum)

An Ethereum execution client meaning it handles transactions, deployment and execution of smart contracts and contains an embedded computer known as the Ethereum Virtual Machine.
Running Geth alongside a consensus client turns a computer into an Ethereum node.

## Halo

The first recursive proof composition without a trusted setup. A proof verifies the correctness of another instance of itself, meaning that the latest mathematical output (one single proof) contains within it a proof that all prior claims to the relevant secret knowledge have themselves been sufficiently proven through a similar process. It allows any amount of computational effort and data to produce a short proof that can be checked quickly.

## Hash

A fixed-length fingerprint of variable-size input, produced by a hash function.

## KZG commitments

A polynomial commitment scheme that allows a prover to compute a commitment to a polynomial, with the properties that this commitment can later be opened at any position: The prover shows that the value of the polynomial at a certain position is equal to a claimed value.
KZG is widely used as it’s applicable both for univariate and k-variate polynomials, is efficient for batch proofs, and is able to generate many proofs at once relatively fast. It is also proof generation time efficient: the time for Prover to commit to a polynomial is linear on the degree of the polynomial.

## Keccak

Cryptographic hash function used in Ethereum.

## Lagrange Interpolation

A formula that helps to find a polynomial which takes on certain values at arbitrary points. Thanks to Lagrange Interpolation the time for a Prover to commit to a polynomial in KZG is linear in the degree of the polynomial.

## Layer 1

Layer 1 (L1) is a blockchain that is self-reliant on its validator set for its security and consensus properties. Ethereum is an example of a layer 1. Blockchains started receiving the moniker of layer 1 once layer 2 became a meaningful area of development.

## Layer 2

Layer 2 (L2) is a category of technical solutions which build upon an L1 with the aim of improving scalability, privacy, or other properties. L2s make use of L1 to bootstrap security and settlement guarantees. The L2 and L1 composition represents an example of a modular blockchain framework.

## Lookup table

Lookup tables express a relation between variables in the format of a table. A prover can rely on such a table of precomputed values in generating a proof without having to do bit by bit arithmetic. These tables can help handle hash functions within circuits in a more friendly manner (that is speeding up decryption and reducing memory requirements).

## Merkle proofs

Hashing the pairs of values at each layer (hashing hashes starting from layer 2) and climbing up the (Merkle) Tree until you obtain the root hash. Merkle proofs help check if the data belongs to a set without having to store the set.

## Merkle tree

TODO

## Modular blockchains

A blockchain that fully outsources at least one of the 4 components (Consensus, Data Availability, Execution, Settlement) to an external chain. For example, rollup is a modular blockchain as it handles transaction executions off-chain and ‘outsources’ data availability and consensus to Ethereum.

## Multi-proof system

A rollup settlement concept that relies on a combination of multiple different proving systems. For example, a combination of fraud proof and validity proof. The goal is to reduce reliance on a single system-type or implementation. A more complex example of a multi-proof system: if anyone submits two conflicting state roots to a prover and both roots pass, that prover is turned off.

## Multi-scalar multiplication (MSM)

The algorithm for calculating the sum of multiple scalar multiplications (products of a real number and a matrix) to reduce the number of group operations as much as possible. As MSM accounts for 80% of Prover’s work fast MSM dominates Prover’s costs improving ZKP efficiency.

## Network

Referring to the Ethereum network, a peer-to-peer network that propagates transactions and blocks to every Ethereum node (network participant).

## Node

A software client that participates in the network.

## Operator

An operator is the entity charged with managing a rollup and progressing its state. While similar to the concept of a proposer, operator is often meant to convey a centralized rollup implementation, with a single operator acting as node, proposer (and prover if ZK).

## Optimistic rollup

A rollup using fraud proofs to offer increased Layer 2 throughput while using the security provided by Layer 1. Optimistic rollups can handle any type of transaction possible in the EVM. Compared to ZK-Rollups, they have larger latency as there is a time window (challenging period) during which anyone can challenge the results of a rollup transaction by computing a fraud proof.

## PLONK

A general-purpose zero-knowledge proof scheme relying on KZG polynomial commitment scheme. It uses a universal (or updateable) trusted setup.
It is theoretically compatible with any (achievable) tradeoff between proof size and security assumptions. For example, if we substitute KZG for FRI PLONK will turn into a kind of STARK.

## Polynomial commitment

A commitment scheme that commits to a univariate polynomial. It is used for Sonic, Marlin, and PLONK proof schemes.

## Pre-compiles

Special contracts that include complex cryptographic computations, but do not require the EVM overhead. For example, some hashing and signature schemes.

## Proposer

An entity that creates a block of transactions, and propagates it to the network for inclusion in the blockchain.

## Proto-danksharding (EIP-4844)

A proposal to implement most of the logic and architecture that make up a full Danksharding spec (eg. transaction formats, verification rules), but not yet actually implementing any sharding. In a proto-danksharding implementation, all validators and users still have to directly validate the availability of the full data.

## Prover

An entity that generates the cryptographic proof to convince the verifier that the statement is true (without revealing its inputs). In a ZK-Rollup, the prover generates the ZK (validity) proof. 
If used in the context of an optimistic rollup, the prover generates the fraud proof to show that an incorrect state was submitted.

## Rewards

In the context of a rollup, an amount of some token allotted as a reward to the participant—proposer and/or prover—who performed a service for the network.

## Rollup

A type of layer 2 scaling solution that batches multiple transactions and submits them to the Ethereum main chain in a single transaction. This allows for reductions in gas costs and increases in transaction throughput. There are Optimistic and Zero-knowledge rollups that use different security methods to offer these scalability gains.

## Rollup-as-a-service

An SDK or service that allows anyone to launch rollups quickly. Emphasis may be placed on the ability to customize the modular components of a rollup: VM, DA layer, proof system.

## Rollup contracts

A bundle of smart contracts running on Ethereum that controls a ZK-Rollup protocol. It includes the main contract which stores rollup blocks, tracks deposits, and monitors state updates, and the verifier contract which verifies zero-knowledge proofs submitted by block proposers.

## RPC (Remote Procedure Call)

A protocol that a program uses to request a service from a program located on another computer in a network without having to understand the network details.

## Scalability

The ability of a blockchain to handle a high level of throughput as measured in transactions per second (TPS), holding decentralization and hardware requirements constant.

## Sequencer

A party responsible for ordering and executing transactions on the rollup. The sequencer verifies transactions, compresses the data into a block, and submits the batch to Ethereum L1 as a single transaction.

## Settlement

The layer of blockchain functionality where the execution of rollups is verified and disputes are resolved. This layer does not exist in monolithic chains and is an optional part of the modular chains.

## Smart contract

A program that executes on the Ethereum computing infrastructure.

## SNARK

Short for "succinct non-interactive argument of knowledge", a SNARK is a widely used type of zero-knowledge proof that is short and fast to verify. Different kinds of SNARKs are usually systematized by proof size, verification time, and type of setup. The most famous SNARKs are Groth16, PLONK/Marlin, Bulletproofs, and STARKs.

## STARK

Short for "scalable transparent argument of knowledge", a STARK is a type of zero-knowledge proof that resolves one of the primary weaknesses of ZK-SNARKs, its reliance on a "trusted setup”. STARKs also come with much simpler cryptographic assumptions, avoiding the need for elliptic curves, pairings, and the knowledge-of-exponent assumption and instead relying purely on hashes and information theory. This means that they are secure even against attackers with quantum computers.

## Succinctness

A property of ZKP that stands for the following terms: (i) the proof of statement is shorter than the statement itself, (ii) the time to verify the proof is faster than just to evaluate the function from scratch.

## Time Delay

In regards to upgradeability, a predefined amount of time that must elapse before the rollup smart contracts or parameters are updated. This protects users from malicious upgrades by giving them time to exit the rollup before upgrades come into effect.

## Transaction

Data committed to the Ethereum Blockchain signed by an originating account, targeting a specific address. The transaction contains metadata such as the gas limit for that transaction.

## Trusted setup (ceremony)

Generation of a piece of data that must then be used for some cryptographic protocol to run. Generating this data requires some secret information. The "trust" comes from the fact that a person generates a secret, uses it to generate the data, and then publishes the data and forgets the secret. Once the data is generated, and the secrets are forgotten, no further participation from the creators of the ceremony is required.
There are two types of trusted setup: (i) trusted setup per circuit where it is generated from scratch for each circuit, (ii) trusted universal (updatable) setup where it can be used for as many circuits as we want.

## Trustlessness

The ability of a network to mediate transactions without any of the involved parties needing to trust a third party.

## Turing complete

A system of data-manipulation rules (such as a computer's instruction set, a programming language, or a cellular automaton) is said to be "Turing complete" or "computationally universal" if it is able to recognize or decide other data-manipulation rule sets.

## Type 1 to 4 ZK-EVMs

**Type 1 ZK-EVM (fully Ethereum-equivalent)**

Fully and uncompromisingly Ethereum-equivalent that is no part of the Ethereum system is changed to make it easier to generate proofs. They do not replace hashes, state trees, transaction trees, precompiles, or any other in-consensus logic, no matter how peripheral.

**Type 2 ZK-EVM (fully EVM-equivalent)**

Exactly EVM-equivalent, but not quite Ethereum-equivalent that is having some differences on the outside, particularly in data structures like the block structure and state tree to make proof generation faster.

**Type 2.5 ZK-EVM (EVM-equivalent, except for gas costs)**

Greatly increasing the gas costs of specific operations in the EVM that are very difficult to ZK-prove such as precompiles, the KECCAK opcode, etc. That significantly improves worst-case prover times. Changing gas costs may reduce developer tooling compatibility and break a few applications.

**Type 3 ZK-EVM (almost EVM-equivalent)**

Removing a few features that are exceptionally hard to implement in a ZK-EVM implementation (precompiles are often at the top of the list) to further improve prover time and make the EVM easier to develop. They also often have minor differences in how they treat contract code, memory, or stack. Type 3 ZK-EVM is compatible with most applications, and requires some re-writing for the rest.

**Type 4 ZK-EVM (high-level-language equivalent)**

Taking smart contract source code written in a high-level language (Solidity, Vyper, etc.) and compiling to some language that is explicitly designed to be ZK-SNARK-friendly. It allows us to avoid ZK-prooving all the different parts of each EVM execution step. But some applications written in Solidity or Vyper and compiled down might not work because contracts may not have the same addresses, handwritten EVM bytecode is more difficult to use, and lots of debugging infrastructure cannot be carried over.

## Upgradeability

The ability for smart contracts and parameters used in a rollup to be updated by holders of an admin key. Upgradeability represents a vector of risk for users, and should be decentralized and combined with time delays for greater security guarantees.

## Validator

A node in a proof-of-stake system responsible for storing data, processing transactions, and adding new blocks to the blockchain. To activate validator software, you need to be able to stake 32 ETH.

## Validity proof

A security model for certain layer 2 solutions (mostly ZK-Rollups) where, to increase speed, transactions are ”rolled up” into batches and submitted to Ethereum in a single transaction. The transaction computation is done off-chain and then supplied to the main chain with a proof of their validity. This method increases the amount of transactions possible while maintaining security.

## Validium

An off-chain solution that uses validity proofs to improve transaction throughput. Unlike Zero-knowledge rollups, validium data isn't stored on layer 1 Mainnet.

## Verifier

An entity in a ZK-Rollup, often a smart contract, that verifies zero-knowledge proofs submitted by a prover.

## Verkle tree

A data storage format of which you can make a proof that it contains some pieces of data to anyone who has the root of the tree. While similar to Merkle Patricia Trees, key differences include a much wider tree format which leads to smaller proof sizes.

## Volition

A hybrid data availability mode, where the user can choose whether to place data on-chain or off-chain.

## Zero-knowledge

A cryptographic technology and sub-discipline of cryptography that allows an individual to prove that a statement or computation is true without revealing any additional information.

## Zero-knowledge proof (ZKP)

A zero-knowledge proof is the resulting output of a zero-knowledge cryptographic method.

## ZK-EVM

A set of circuits that prove the execution of the Ethereum Virtual Machine. It is the core component of a ZK-Rollup that generates Zero-knowledge proofs to verify the correctness of programs. Increasingly, it is used to describe a ZK-Rollup as whole which is EVM-compatible, as opposed to just the set of circuits.

## ZK-Rollup

A rollup that uses ZKPs (also often called validity proofs) to validate the correctness of the state transition function and update the rollup state. This is one of two main types of rollup constructions, along with optimistic rollups. In general, ZK-Rollups do not provide privacy preserving properties; privacy preserving ZK-Rollups are sometimes called ZK-ZK-Rollups.

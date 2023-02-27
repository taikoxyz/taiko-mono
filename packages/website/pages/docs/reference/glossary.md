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

The computation model of ZK-[SNARKs](#SNARK).

## Blobs

The data that a [rollup](#rollup) publishes to its [L1](#layer-1)/[data availability (DA)](#data-availability) layer. They consist of the [L2](#layer-2) [transactions](#transaction) that are rolled up, along with some metadata. Blobs are introduced as a new transaction type within Ethereum with [EIP-4844](#Proto-danksharding-(EIP-4844)), and has rollup scaling specifically in mind. Blobs persist on Ethereum’s Beacon Chain ephemerally.

## Blobspace

The storage area within Ethereum’s Beacon [nodes](#node) where [blobs](#blobs) are published by [rollups](#rollup) and ephemerally stored.

## Block

An ordered list of transactions and chain-related metadata that gets bundled together and published to the [L1](#Layer-1)/[DA](#Data-availability) layer. [Nodes](#node) execute the [transactions](#Transaction) contained within blocks to change the [rollup](#rollup) chain’s state. Protocol rules dictate what constitutes a valid block, and invalid blocks are skipped over.

## Bridge

A message-passing protocol between two blockchains (between [L1](#layer-1) and [L2](#layer-2), and between L2s). At its most basic, a bridge consists of a [smart contract](#smart-contract) which can escrow funds on one side of the bridge, and instruct the release or minting of corresponding assets on the other side. How these instructions are validated is a critical factor in assessing the trust assumptions of a bridge.

## Bytecode

Generally, an instruction set designed for efficient execution by a software interpreter or a virtual machine. Unlike human-readable source code, bytecode is expressed numerically. Within the context of [rollups](#rollup), often related to the concept of [compatibility](#compatibility): whether the bytecode of programs on the rollup are capable of being run as-is on Ethereum as well, and vice versa.

## Challenge period

In [optimistic rollups](#optimistic-rollup), the window of time wherein [network](#network) participants can assert that some fraud was included in a prior block. Most optimistic rollups currently specify a challenge window of 7 days. By extending the period, there is more time for participants to guard against fraud (invalid state transitions), but also more time until [finality](#finality) is reached.

## Circuit

A program written for the purposes of being proven within a proving system. A circuit is a mathematical representation of the computation to be executed, and is therefore sometimes referred to as an arithmetic circuit. Circuits can be written in different languages, ranging from low-level to high-level.

## Client

Sometimes labelled interchangeably as a “[node](#node)”, they are tasked with processing [transactions](#Transaction) and managing the [rollup’s](#rollup) state. They run the computations for each transaction according to the rollup’s virtual machine and protocol rules. If comparing to Ethereum clients, these would be execution clients such as [Geth](#Geth), as opposed to consensus clients.

## Consensus

An agreement on the latest and correct state of a blockchain. Unlike [L1](#layer-1) blockchains which coordinate participating [nodes](#node) with consensus rules, [rollups](#rollup) rely on L1s for reaching consensus by checking the state of the rollup [smart contract](#Smart-contract) deployed thereon.

## Compatibility

The degree to which a [rollup](#rollup) can make use of existing patterns, code, and tooling from another blockchain or development environment. Today, this typically refers to how well rollups and developers thereon can make use of the [Ethereum Virtual Machine](#Ethereum-Virtual-Machine-(EVM)), existing [smart contracts](#Smart-contract), and other Ethereum infrastructure.

## Commitment Scheme

A cryptographic primitive that (i) allows one (usually a [prover](#prover)) to commit to a chosen statement and send this commitment to the [verifier](#verifier) while keeping it hidden to others, and (ii) allows verifier to check the commitment and accept or reject it.
The commitment scheme should satisfy two properties: (i) it should be binding; that is, once the prover has committed she is bound to the message she has committed, (ii) it should be hiding; that is, the commitment reveals nothing new about the message to the verifier.

## Completeness

One of three properties of [zero-knowledge proofs](#zero-knowledge-proof), completeness states that if a statement is true, an honest [verifier](#verifier) will be convinced of this by an honest [prover](#prover).

## Danksharding

A sharding design proposed for Ethereum. Instead of providing more space for [transactions](#transaction), Ethereum sharding provides more space for [blobs](#blobs) of data. Verifying a blob simply requires checking that the blob is available - that it can be downloaded from the [network](#network). The data space in these blobs is expected to be used by [layer-2](#Layer-2) [rollup](#rollup) protocols.
In comparison to other sharding mechanisms, where there are a fixed number of shards with distinct [blocks](#block) and distinct block [proposers](#proposer), in Danksharding there is only one proposer that chooses all transactions and all data that go into that slot.

## Data availability

The property of a [rollup’s](#rollup) state being reachable by any node retrieving the inputs that were rolled up and executed to reach said state. Data availability (DA), specifically decoupling it from the rollup [nodes](#node) themselves, is the preeminent notion which allows a rollup to scale securely. A rollup is faced with a decision of what to use as a DA layer (data storage) to guarantee that any node can retrieve this data, permissionlessly under any circumstance. For this reason, using Ethereum for DA currently provides the strongest security guarantees.

## Decentralization

The concept of moving the control and execution of processes away from a central entity. In the context of [rollups](#rollup), there are several factors which separately can be more or less decentralized, leading to the degree to which the rollup as a whole is uncapturable by a central entity. The most significant factors include who can run a [node](#node) (and how easily), who can [propose](#proposer) rollup [blocks](#block), who can [prove](#prover) blocks (in [ZK-Rollups](#ZK-Rollup)), and who can [upgrade](#Upgradeability) the rollup [smart contracts](#Smart-contract).

## Deterministic

The concept of some function or process having a single outcome that is knowable by all participants. In the context of a [rollup](#rollup), it generally refers to the new state being calculable given a prior state and a list of [transactions](#transaction) to be executed.

## Ethereum Virtual Machine (EVM)

A stack-based virtual machine that executes [bytecode](#bytecode). In Ethereum, the execution model specifies how the system state is altered given a series of bytecode instructions and a small tuple of environmental data. In the context of [rollups](#rollup), the EVM is a choice of execution environment that rollups could implement, as in the case of EVM [ZK-Rollups](#ZK-Rollup) ([ZK-EVMs](#ZK-EVM)) and EVM [optimistic rollups](#optimistic-rollup).

## Execution environment

Refers to both the environment where transactions are processed, constituted by the execution [clients](#client), as well as the virtual machine model which the clients run.

## Equivalence

A perfect degree of [compatibility](#compatibility); where one system or concept is indistinguishable from another in the domain being compared. In the context of [rollups](#rollup), it generally refers to the proximity to the [EVM](#Ethereum-Virtual-Machine-(EVM)) and to Ethereum architecture.

## Escape hatch

The facility for any user of a [rollup](#rollup) to exit the system with their assets under any circumstance. Most relevant in rollups with a centralized [proposer](#proposer), wherein users do not have the ability to propose blocks, but can nonetheless exit the rollup by interacting with a smart contract on L1.

## Finality

The guarantee that a set of [transactions](#Transaction) before a given time will not change and can't be reverted. When finality is reached differs meaningfully between ZK ([validity](#Validity-proof)) and [optimistic rollups](#optimistic-rollup).

## Fast Fourier transform (FFT)

An algorithm that computes the Discrete Fourier Transform (DFT) of a sequence in a more efficient manner; that is, taking O(n * log(n)) instead of O(n * n). It is used for extremely fast multiplication of large numbers, multiplication of polynomials, and extremely fast generation and recovery of erasure codes.

## Fraud proof

Also referred to as a fault proof, it is the construction of an assertion that fraud was perpetrated on an [optimistic rollup](#optimisitc-rollup). More concretely, that an invalid state transition took place according to the protocol rules. The submitter of a fraud proof would expect a [reward](#rewards) from the optimistic rollup protocol for helping maintain the integrity of the system.

## FRI

A proximity test method that is used to determine whether a set of points is mostly on a polynomial with a degree less than a specified value. It resembles the [FFT](#Fast-Fourier-transform-(FFT)) but the arithmetic complexity of its [prover](#prover) is strictly linear and that of the [verifier](#verifier) is strictly logarithmic.

## Gas

A virtual fuel used to execute [smart contracts](#smart-contract) on a [rollup](#rollup). The [EVM](#Ethereum-Virtual-Machine-(EVM)) (or other VM within the rollup) uses an accounting mechanism to correspond the consumption of gas to the consumption of computing resources, and to limit the consumption of computing resources.

## Gas limit

The maximum amount of [gas](#gas) a [transaction](#transaction) or [block](#block) may consume.

## Gas price

Price in ether of one unit of [gas](#gas) specified in a [transaction](#transaction).

## General-purpose rollup

A [rollup](#rollup) that supports arbitrary computations, allowing for the development of arbitrary applications and functionalities. 

## Geth (Go Ethereum)

An Ethereum execution [client](#client), meaning it handles [transactions](#transaction), deployment and execution of smart contracts and contains an embedded computer known as the [Ethereum Virtual Machine](#Ethereum-Virtual-Machine-(EVM)). Running Geth alongside a consensus client turns a computer into a full Ethereum node, or validator.

## Halo

The first recursive proof composition without a [trusted setup](#Trusted-setup-(ceremony)). A proof verifies the correctness of another instance of itself, meaning that the latest mathematical output (one single proof) contains within it a proof that all prior claims to the relevant secret knowledge have themselves been sufficiently proven through a similar process. It allows any amount of computational effort and data to produce a short proof that can be checked quickly.

## Hash

A fixed-length fingerprint of variable-size input, produced by a hash function.

## KZG commitments

A [polynomial commitment](#polynomial-commitment) scheme that allows a prover to compute a commitment to a polynomial, with the properties that this commitment can later be opened at any position: the [prover](#prover) shows that the value of the polynomial at a certain position is equal to a claimed value.
KZG is widely used as it’s applicable both for univariate and k-variate polynomials, is efficient for batch proofs, and is able to generate many proofs at once relatively fast. It is also proof generation time efficient: the time for prover to commit to a polynomial is linear on the degree of the polynomial.

## Keccak

Cryptographic hash function used in Ethereum.

## Lagrange Interpolation

A formula that helps to find a polynomial which takes on certain values at arbitrary points. Thanks to Lagrange Interpolation the time for a prover to commit to a polynomial in [KZG](#KZG-commitments) is linear in the degree of the polynomial.

## Layer 1

Layer 1 (L1) is a blockchain that is self-reliant on its [validator](#validator) set for its security and [consensus](#consensus) properties. Ethereum is an example of a layer 1. Blockchains started receiving the moniker of layer 1 once layer 2 became a meaningful area of development.

## Layer 2

Layer 2 (L2) is a category of technical solutions which build upon an [L1](#Layer-1) with the aim of improving [scalability](#Scalability), privacy, or other properties. L2s make use of L1 to bootstrap security and [settlement](#Settlement) guarantees. The L2 and L1 composition represents an example of a [modular blockchain](#modular-blockchains) framework.

## Lookup table

Lookup tables express a relation between variables in the format of a table. A [prover](#prover) can rely on such a table of precomputed values in generating a proof without having to do bit by bit arithmetic. These tables can help handle hash functions within [circuits](#circuit) in a more friendly manner (that is speeding up decryption and reducing memory requirements).

## Merkle proofs

[Hashing](#hash) the pairs of values at each layer (hashing hashes starting from [layer 2](#layer-2) and climbing up the (Merkle) Tree until you obtain the root hash. Merkle proofs help check if the data belongs to a set without having to store the set.

## Merkle tree

A hash-based data structure in which each leaf [node](#node) is a [hash](#hash) of a [block](#block) of data, and each non-leaf node is a hash of its children. The root of the tree is a cryptographic fingerprint of the entire data structure. Merkle trees (Merkle Patricia Tries) are used in Ethereum to efficiently store key-value pairs.

## Modular blockchains

A blockchain that fully outsources at least one of the 4 components ([Consensus](#Consensus), [Data Availability](#Data-availability), Execution, [Settlement](#Settlement)) to an external chain. For example, [rollup](#rollup) is a modular blockchain as it handles [transaction](#Transaction) executions off-chain and ‘outsources’ data availability and consensus to Ethereum.

## Multi-proof system

A [rollup](#rollup) [settlement](#settlement) concept that relies on a combination of multiple different proving systems. For example, a combination of [fraud proof](#Fraud-proof) and [validity proof](#Validity-proof). The goal is to reduce reliance on a single system-type or implementation. A more complex example of a multi-proof system: if anyone submits two conflicting state roots to a [prover](#prover) and both roots pass, that prover is turned off.

## Multi-scalar multiplication (MSM)

The algorithm for calculating the sum of multiple scalar multiplications (products of a real number and a matrix) to reduce the number of group operations as much as possible. As MSM accounts for 80% of [prover](#prover)’s work fast MSM dominates prover’s costs improving [ZKP](#Zero-knowledge-proof-(ZKP)) efficiency.

## Network

A constellation of [nodes](#node) (peers) that communicate via a peer-to-peer protocol, for example, in propagating [transactions](#transaction) and [blocks](#block) to other nodes.

## Node

A software [client](#Client) that participates in the [network](#Network).

## Operator

An operator is the entity charged with managing a [rollup](#rollup) and progressing its state. While similar to the concept of a [proposer](#proposer), operator is often meant to convey a centralized rollup implementation, with a single operator acting as [node](#node), proposer (and [prover](#prover) if [ZK](#Zero-knowledge)).

## Optimistic rollup

A [rollup](#rollup) using [fraud proofs](#fraud-proof) to offer increased [Layer 2](#Layer-2) throughput while using the security provided by [Layer 1](#Layer-1). Optimistic rollups can handle any type of [transaction](#transaction) possible in the [EVM](#Ethereum-Virtual-Machine-(EVM)). Compared to [ZK-Rollups](#ZK-Rollup), they have larger latency as there is a time window ([challenging period](#Challenge-period)) during which anyone can challenge the results of a rollup transaction by computing a fraud proof.

## PLONK

A general-purpose [zero-knowledge](#Zero-knowledge) proof scheme relying on [KZG polynomial commitment scheme](#KZG-commitments). It uses a universal (or updateable) [trusted setup](#Trusted-setup-(ceremony)).
It is theoretically [compatible](#Compatibility) with any (achievable) tradeoff between proof size and security assumptions. For example, if we substitute KZG for [FRI](#FRI) PLONK will turn into a kind of [STARK](#STARK).

## Polynomial commitment

A commitment scheme that commits to a univariate polynomial. It is used for Sonic, Marlin, and [PLONK](#PLONK) proof schemes.

## Pre-compiles

Special [contracts](#Smart-contract) that include complex cryptographic computations, but do not require the [EVM](#Ethereum-Virtual-Machine-(EVM)) overhead. For example, some [hashing](#hash) and signature schemes.

## Proposer

An entity that creates a [block](#block) of [transactions](#transaction), and propagates it to the [network](#network) for inclusion in the blockchain.

## Proto-danksharding (EIP-4844)

A proposal to implement most of the logic and architecture that make up a full [Danksharding](#Danksharding) spec (eg. transaction formats, verification rules), but not yet actually implementing any sharding. In a proto-danksharding implementation, all [validators](#Validator) and users still have to directly validate the [availability](#Data-availability) of the full data.

## Prover

An entity that generates the cryptographic proof to convince the [verifier](#verifier) that the statement is true (without revealing its inputs). In a [ZK-Rollup](#ZK-Rollup), the prover generates the [ZK (validity) proof](#Validity-proof) to submit to the verifier [contract](#Smart-contract).
If used in the context of an [optimistic rollup](#optimistic-rollup), the prover generates the [fraud proof](#fraud-proof) to show that an incorrect state was submitted.

## Rewards

In the context of a [rollup](#rollup), an amount of some token allotted as a reward to the participant—[proposer](#proposer) and/or [prover](#prover)—who performed a service for the [network](#network).

## Rollup

A type of [layer 2](#Layer-2) [scaling](#Scalability) solution that batches multiple [transactions](#Transaction) and submits them to the Ethereum main chain in a single transaction. This allows for reductions in gas costs and increases in transaction throughput. There are [Optimistic](#Optimistic-rollup) and [Zero-knowledge rollups](#ZK-Rollup) that use different security methods to offer these scalability gains.

## Rollup-as-a-service

An SDK or service that allows anyone to launch [rollups](#rollup) quickly. Emphasis may be placed on the ability to customize the [modular](#Modular-blockchains) components of a rollup: Virtual Machine, [Data Availability](#Data-availability) layer, proof system.

## Rollup contracts

A bundle of [smart contracts](#Smart-contract) running on Ethereum that controls a [rollup](#rollup) protocol. It includes the main contract which stores rollup [blocks](#block), tracks deposits, and monitors state updates, and the [verifier](#verifier) contract which verifies [zero-knowledge proofs](#Zero-knowledge-proof-(ZKP)) submitted by [provers](#prover).

## RPC (Remote Procedure Call)

A protocol that a program uses to request a service from a program located on another computer in a [network](#network) without having to understand the network details.

## Scalability

The ability of a blockchain to handle a high level of throughput as measured in [transactions](#transaction) per second (TPS), holding [decentralization](#Decentralization) and hardware requirements constant.

## Sequencer

A party responsible for ordering and executing [transactions](#Transaction) on the [rollup](#rollup). The sequencer verifies transactions, compresses the data into a [block](#block), and submits the batch to Ethereum L1 as a single transaction. Often synonymous with [proposer](#proposer).

## Settlement

The mechanism with which the execution of [rollup](#rollup) [blocks](#block) and the resultant state is verified and possible disputes are resolved. In the context of rollups or other [modular blockchains](#Modular-blockchains), it often refers to the proof system used--[validity (ZK)](#Validity-proof) or [fraud proofs](#Fraud-proof), or a combination thereof. Sometimes it will refer to this mechanism along with where the mechanism's outputs are ultimately published and verified, as in Ethereum being a settlement layer by verifying the proof(s).

## Smart contract

A program that executes on the Ethereum computing infrastructure, or other blockchain.

## SNARK

Short for "[succinct](#Succinctness) non-interactive argument of knowledge", a SNARK is a widely used type of [zero-knowledge proof](#Zero-knowledge-proof-(ZKP)) that is short and fast to verify. Different kinds of SNARKs are usually systematized by proof size, verification time, and type of setup. The most famous SNARKs are Groth16, [PLONK](#PLONK)/Marlin, Bulletproofs, and [STARKs](#STARK).

## STARK

Short for "[scalable](#Scalability) transparent argument of knowledge", a STARK is a type of [zero-knowledge proof](#Zero-knowledge-proof-(ZKP)) that resolves one of the primary weaknesses of ZK-[SNARKs](#SNARK), its reliance on a "[trusted setup](#Trusted-setup-(ceremony))”. STARKs also come with much simpler cryptographic assumptions, avoiding the need for elliptic curves, pairings, and the knowledge-of-exponent assumption and instead relying purely on [hashes](#hash) and information theory. This means that they are secure even against attackers with quantum computers.

## Succinctness

A property of [ZKP](#Zero-knowledge-proof-(ZKP)) that stands for the following terms: (i) the proof of statement is shorter than the statement itself, (ii) the time to verify the proof is faster than just to evaluate the function from scratch.

## Time Delay

In regards to [upgradeability](#Upgradeability), a predefined amount of time that must elapse before the [rollup](#rollup) [smart contracts](#Smart-contract) or parameters are updated. This protects users from malicious upgrades by giving them time to exit the rollup before upgrades come into effect.

## Transaction

Data committed to the Ethereum Blockchain signed by an originating account, targeting a specific address. The transaction contains metadata such as the [gas limit](#Gas-limit) for that [transaction](#Transaction).

## Trusted setup (ceremony)

Generation of a piece of data that must then be used for some cryptographic protocol to run. Generating this data requires some secret information. The "trust" comes from the fact that a person generates a secret, uses it to generate the data, and then publishes the data and forgets the secret. Once the data is generated, and the secrets are forgotten, no further participation from the creators of the ceremony is required.
There are two types of trusted setup: (i) trusted setup per [circuit](#circuit) where it is generated from scratch for each circuit, (ii) trusted universal (updatable) setup where it can be used for as many circuits as we want.

## Trustlessness

The ability of a [network](#Network) to mediate [transactions](#Transaction) without any of the involved parties needing to trust a third party.

## Turing complete

A system of data-manipulation rules (such as a computer's instruction set, a programming language, or a cellular automaton) is said to be "Turing complete" or "computationally universal" if it is able to recognize or decide other data-manipulation rule sets.

## Type 1 to 4 ZK-EVMs

**Type 1 [ZK-EVM](#ZK-EVM) (fully Ethereum-equivalent)**

Fully and uncompromisingly Ethereum-equivalent. No part of the Ethereum system is changed to make it easier to generate proofs. They do not replace [hashes](#hash), state trees, transaction trees, precompiles, or any other in-[consensus](#consensus) logic, no matter how peripheral.

**Type 2 [ZK-EVM](#ZK-EVM) (fully [EVM](#Ethereum-Virtual-Machine-(EVM))-equivalent)**

Exactly EVM-equivalent, but not quite Ethereum-equivalent. There are some differences to Ethereum outside the EVM, particularly in data structures like the [block](#block) structure and state tree to make proof generation faster.

**Type 2.5 [ZK-EVM](#ZK-EVM) ([EVM](#Ethereum-Virtual-Machine-(EVM))-equivalent, except for gas costs)**

Increasing the gas costs of specific operations in the EVM that are very difficult to ZK-prove such as [precompiles](#Pre-compiles), the [KECCAK](#Keccak) opcode, etc. This would significantly improve worst-case prover times. Changing gas costs may reduce developer tooling [compatibility](#Compatibility) and break a few applications.

**Type 3 [ZK-EVM](#ZK-EVM) (almost [EVM](#Ethereum-Virtual-Machine-(EVM))-equivalent)**

Removing a few features that are exceptionally hard to implement in a ZK-EVM implementation ([precompiles](#Pre-compiles) are often at the top of the list) to further improve prover time and make the EVM easier to develop. They also often have minor differences in how they treat [contract](#Smart-contract) code, memory, or stack. Type 3 ZK-EVM is [compatible](#Compatibility) with most applications, and requires some re-writing for the rest.

**Type 4 [ZK-EVM](#ZK-EVM) (high-level-language equivalent)**

Taking [smart contract](#Smart-contract) source code written in a high-level language (Solidity, Vyper, etc.) and compiling to some language that is explicitly designed to be [ZK](#Zero-knowledge)-friendly. It allows us to avoid ZK-proving all the different parts of each [EVM](#Ethereum-Virtual-Machine-(EVM)) execution step. Some applications written in Solidity or Vyper and then compiled down might not work because contracts may not have the same addresses, handwritten EVM [bytecode](#Bytecode) is more difficult to use, and lots of debugging infrastructure cannot be carried over.

## Upgradeability

The ability for [smart contracts](#Smart-contract) and parameters used in a [rollup](#rollup) to be updated by holders of an admin key. Upgradeability represents a vector of risk for users, and should be decentralized and combined with time delays for greater security guarantees.

## Validator

A [node](#node) in a proof-of-stake system responsible for storing data, processing [transactions](#transaction), and adding new [blocks](#block) to the blockchain. To activate validator software, you need to be able to stake 32 ETH.

## Validity proof

A security model for certain [layer 2](#Layer-2) solutions (mostly [ZK-Rollups](#ZK-Rollup)) where, to increase speed, [transactions](#transaction) are ”rolled up” into batches and submitted to Ethereum in a single transaction. The transaction computation is done off-chain and then supplied to the main chain with a proof of their validity. This method increases the amount of transactions possible while maintaining security.

## Validium

An off-chain solution that uses [validity proofs](#Validity-proof) to improve [transaction](#Transaction) throughput. Unlike [Zero-knowledge rollups](#ZK-Rollup), validium data isn't stored on [layer 1](#Layer-1) Mainnet.

## Verifier

An entity in a [ZK-Rollup](#ZK-Rollup), often a [smart contract](#Smart-contract), that verifies [zero-knowledge proofs](#Zero-knowledge-proof-(ZKP) submitted by a [prover](#prover).

## Verkle tree

A data storage format of which you can make a proof that it contains some pieces of data to anyone who has the root of the tree. While similar to [Merkle Patricia Trees](#Merkle-tree), key differences include a much wider tree format which leads to smaller proof sizes.

## Volition

A hybrid [data availability](#Data-availability) mode, where the user can choose whether to place data on-chain or off-chain.

## Zero-knowledge

A cryptographic technology and sub-discipline of cryptography that allows an individual to prove that a statement or computation is true without revealing any additional information.

## Zero-knowledge proof (ZKP)

A zero-knowledge proof is the resulting output of a [zero-knowledge](#Zero-knowledge-proof-(ZKP)) cryptographic method.

## ZK-EVM

A set of [circuits](#circuit) that prove the execution of the [Ethereum Virtual Machine](#Ethereum-Virtual-Machine-(EVM)). It is the core component of a ZK-Rollup that generates [Zero-knowledge proofs](#Zero-knowledge-proof-(ZKP)) to verify the correctness of programs. Increasingly, it is used to describe a ZK-Rollup as whole which is EVM-[compatible](#Compatibility), as opposed to just the set of circuits.

## ZK-Rollup

A [rollup](#rollup) that uses [ZKPs](#Zero-knowledge-proof-(ZKP)) (also often called [validity proofs](#Validity-proof) to validate the correctness of the state transition function and update the rollup state. This is one of two main types of rollup constructions, along with [optimistic rollups](#Optimistic-rollup). In general, ZK-Rollups do not provide privacy preserving properties; privacy preserving ZK-Rollups are sometimes called ZK-ZK-Rollups.

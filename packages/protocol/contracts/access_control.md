# Actors and Privileges Documentation

## Introduction

This document provides a comprehensive overview of the actors involved in the smart contract system and outlines their respective privileges and roles.
Different `roles` (we call them `domain`) are granted via `AddressManager` contract's `setAddress()` function. Idea is very similar Optimism's `AddressManager` except that we use the `chainId + domainName` as the key for a given address. We need so, because for bridging purposes, the destination chain's bridge address needs to be inculded signaling the messgae hash is tamper-proof.
Every contract which needs some role-based authentication, needs to inherit from `AddressResolver` contract, which will serve as a 'middleman/lookup' by querying the `AddressManager` per given address is allowed to act on behalf of that domain or not.

## 1. Domains (≈role per chainId)

In the context of the smart contract system, various actors play distinct roles. Each actor is associated with specific responsibilities and privileges within the system. When there is a modifier called `onlyFromNamed` or `onlyFromNamed2`, it means we are checking access through the before mentioned contracts (`AddressResolver` and `AddressManager`), and one function maximum allows up to 2 domains (right now, but it might change when e.g.`DAO` is set up) can be given access.

### 1.1 Taiko

- **Role**: This domain role is given to TaikoL1 smart contract.
- **Privileges**:
  - Possibility to mint/burn the taiko token
  - Possibility to mint/burn erc20 tokens (I think we should remove this privilege)

### 1.2 Bridge

- **Role**: This domain role is given to Bridge smart contracts (both chains).
- **Privileges**:
  - The right to trigger transfering/minting the tokens (on destination chain) (be it ERC20, ERC721, ERC1155) from the vault contracts
  - The right to trigger releasing the custodied assets on the source chain (if bridging is not successful)

### 1.3 ERCXXX_Vault

- **Role**: This role is givne to respective token vault contracts (ERC20, ERC721, ERC1155)
- **Privileges**:
  - Part of token briding, the possibility to burn and mint the respective standard tokens (no autotelic minting/burning)

### ...

## 2. Different access modifiers

Beside the `onlyFromNamed` or `onlyFromNamed2` modifiers, we have others such as:

### 2.1 onlyOwner

- **Description**: Only owner can be granted access.
- **Associated contracts**: TaikoToken, AddressManager, EtherVault

### 2.2 onlyAuthorized

- **Description**: Only authorized (by owner) can be granted access - the address shall be a smart contract. (`Bridge` in our case)
- **Associated Actors**: EtherVault

## Conclusion

This documentation ensures that all stakeholders understand their roles and responsibilities within the system, contributing to its security and effectiveness.

Please ensure that this document is kept up to date as changes are made to the smart contract system and its actors or privileges.

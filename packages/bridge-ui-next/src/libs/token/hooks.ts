"use client";

/**
 * TanStack React Query hooks for the token lib.
 *
 * These are THIN wrappers around the pure async functions in this folder — the
 * underlying functions are unchanged and can still be called imperatively by any
 * non-React caller. Read-only on-chain/HTTP fetchers become `useQuery`; writes and
 * pre-flight checks (mint, checkMintable) become `useMutation`.
 *
 * Query keys are structured arrays including chain ids + address + token identity.
 * Any bigint embedded in a key is stringified so TanStack's key hashing stays stable.
 */
import {
  type UseQueryOptions,
  useMutation,
  useQuery,
} from "@tanstack/react-query";
import type { Address, Hash } from "viem";

import { checkMintable } from "./checkMintable";
import { checkOwnershipOfNFT, checkOwnershipOfNFTs } from "./checkOwnership";
import { detectContractType } from "./detectContractType";
import { fetchBalance } from "./fetchBalance";
import { getAddress } from "./getAddress";
import { getCanonicalInfoForToken } from "./getCanonicalInfoForToken";
import { getTokenAddresses } from "./getTokenAddresses";
import { getTokenApprovalStatus } from "./getTokenApprovalStatus";
import { getTokenWithInfoFromAddress } from "./getTokenWithInfoFromAddress";
import { mapTransactionHashToNFT } from "./mapTransactionHashToNFT";
import { mint } from "./mint";
import { type GetTokenInfo, type NFT, type Token, TokenType } from "./types";

/** Stable identity string for a token (handles ETH having no address). */
function tokenIdentity(token?: Token | NFT | null): string {
  if (!token) return "none";
  const addresses = Object.entries(token.addresses ?? {})
    .map(([chainId, address]) => `${chainId}:${address}`)
    .join(",");
  const tokenId = "tokenId" in token ? `#${(token as NFT).tokenId}` : "";
  return `${token.type}:${token.symbol}:${addresses}${tokenId}`;
}

// ----------------------------------------------------------------------------
// Balance
// ----------------------------------------------------------------------------

type UseTokenBalanceArgs = {
  userAddress?: Address;
  token?: Token | NFT;
  srcChainId?: number;
  destChainId?: number;
};

export function useTokenBalance(
  { userAddress, token, srcChainId, destChainId }: UseTokenBalanceArgs,
  options?: Partial<UseQueryOptions<Awaited<ReturnType<typeof fetchBalance>>>>,
) {
  return useQuery({
    queryKey: ["balance", srcChainId, userAddress, tokenIdentity(token)],
    queryFn: () =>
      fetchBalance({
        userAddress: userAddress as Address,
        token,
        srcChainId,
        destChainId,
      }),
    enabled: Boolean(userAddress),
    ...options,
  });
}

// ----------------------------------------------------------------------------
// Token address resolution
// ----------------------------------------------------------------------------

export function useTokenAddress(
  args: { token?: Token; srcChainId?: number; destChainId?: number },
  options?: Partial<UseQueryOptions<Awaited<ReturnType<typeof getAddress>>>>,
) {
  const { token, srcChainId, destChainId } = args;
  return useQuery({
    queryKey: ["tokenAddress", srcChainId, destChainId, tokenIdentity(token)],
    queryFn: () =>
      getAddress({
        token: token as Token,
        srcChainId: srcChainId as number,
        destChainId,
      }),
    enabled: Boolean(token) && Boolean(srcChainId),
    ...options,
  });
}

export function useTokenAddresses(
  args: Partial<GetTokenInfo>,
  options?: Partial<
    UseQueryOptions<Awaited<ReturnType<typeof getTokenAddresses>>>
  >,
) {
  const { token, srcChainId, destChainId } = args;
  return useQuery({
    queryKey: ["tokenAddresses", srcChainId, destChainId, tokenIdentity(token)],
    queryFn: () =>
      getTokenAddresses({
        token: token as Token | NFT,
        srcChainId: srcChainId as number,
        destChainId: destChainId as number,
      }),
    enabled: Boolean(token) && Boolean(srcChainId) && Boolean(destChainId),
    ...options,
  });
}

export function useCanonicalInfo(
  args: Partial<GetTokenInfo>,
  options?: Partial<
    UseQueryOptions<Awaited<ReturnType<typeof getCanonicalInfoForToken>>>
  >,
) {
  const { token, srcChainId, destChainId } = args;
  return useQuery({
    queryKey: ["canonicalInfo", srcChainId, destChainId, tokenIdentity(token)],
    queryFn: () =>
      getCanonicalInfoForToken({
        token: token as Token | NFT,
        srcChainId: srcChainId as number,
        destChainId: destChainId as number,
      }),
    enabled: Boolean(token) && Boolean(srcChainId) && Boolean(destChainId),
    ...options,
  });
}

// ----------------------------------------------------------------------------
// Contract type detection
// ----------------------------------------------------------------------------

export function useContractType(
  args: { contractAddress?: Address; chainId?: number },
  options?: Partial<UseQueryOptions<TokenType>>,
) {
  const { contractAddress, chainId } = args;
  return useQuery({
    queryKey: ["contractType", chainId, contractAddress],
    queryFn: () =>
      detectContractType(contractAddress as Address, chainId as number),
    enabled: Boolean(contractAddress) && Boolean(chainId),
    ...options,
  });
}

// ----------------------------------------------------------------------------
// Token + info
// ----------------------------------------------------------------------------

type UseTokenWithInfoArgs = {
  contractAddress?: Address;
  srcChainId?: number;
  owner?: Address;
  tokenId?: number;
  type?: TokenType;
};

export function useTokenWithInfo(
  args: UseTokenWithInfoArgs,
  options?: Partial<UseQueryOptions<Token | NFT>>,
) {
  const { contractAddress, srcChainId, owner, tokenId, type } = args;
  return useQuery({
    queryKey: [
      "tokenWithInfo",
      srcChainId,
      contractAddress,
      owner,
      tokenId,
      type,
    ],
    queryFn: () =>
      getTokenWithInfoFromAddress({
        contractAddress: contractAddress as Address,
        srcChainId: srcChainId as number,
        owner,
        tokenId,
        type,
      }),
    enabled: Boolean(contractAddress) && Boolean(srcChainId),
    ...options,
  });
}

// ----------------------------------------------------------------------------
// Ownership
// ----------------------------------------------------------------------------

export function useNftOwnership(
  args: { nft?: NFT; accountAddress?: Address; chainId?: number },
  options?: Partial<
    UseQueryOptions<Awaited<ReturnType<typeof checkOwnershipOfNFT>>>
  >,
) {
  const { nft, accountAddress, chainId } = args;
  return useQuery({
    queryKey: ["nftOwnership", chainId, accountAddress, tokenIdentity(nft)],
    queryFn: () =>
      checkOwnershipOfNFT(
        nft as NFT,
        accountAddress as Address,
        chainId as number,
      ),
    enabled: Boolean(nft) && Boolean(accountAddress) && Boolean(chainId),
    ...options,
  });
}

export function useNftsOwnership(
  args: { nfts?: NFT[]; accountAddress?: Address; chainId?: number },
  options?: Partial<
    UseQueryOptions<Awaited<ReturnType<typeof checkOwnershipOfNFTs>>>
  >,
) {
  const { nfts, accountAddress, chainId } = args;
  return useQuery({
    queryKey: [
      "nftsOwnership",
      chainId,
      accountAddress,
      (nfts ?? []).map(tokenIdentity).join("|"),
    ],
    queryFn: () =>
      checkOwnershipOfNFTs(
        nfts as NFT[],
        accountAddress as Address,
        chainId as number,
      ),
    enabled:
      Boolean(nfts?.length) && Boolean(accountAddress) && Boolean(chainId),
    ...options,
  });
}

// ----------------------------------------------------------------------------
// Approval status
// ----------------------------------------------------------------------------

export function useTokenApprovalStatus(
  token: Maybe<Token | NFT>,
  options?: Partial<
    UseQueryOptions<Awaited<ReturnType<typeof getTokenApprovalStatus>>>
  >,
) {
  return useQuery({
    queryKey: ["tokenApprovalStatus", tokenIdentity(token)],
    queryFn: () => getTokenApprovalStatus(token),
    enabled: Boolean(token),
    ...options,
  });
}

// ----------------------------------------------------------------------------
// Transaction-hash -> NFT mapping
// ----------------------------------------------------------------------------

export function useNftFromTxHash(
  args: { hash?: Hash; srcChainId?: number; type?: TokenType },
  options?: Partial<UseQueryOptions<NFT>>,
) {
  const { hash, srcChainId, type } = args;
  return useQuery({
    queryKey: ["nftFromTxHash", srcChainId, hash, type],
    queryFn: () =>
      mapTransactionHashToNFT({
        hash: hash as Hash,
        srcChainId: srcChainId as number,
        type: type as TokenType,
      }),
    enabled: Boolean(hash) && Boolean(srcChainId) && Boolean(type),
    ...options,
  });
}

// ----------------------------------------------------------------------------
// Mutations
// ----------------------------------------------------------------------------

/** Mints a free-mint test ERC20. Rejects exactly like the underlying `mint()`. */
export function useMintToken() {
  return useMutation({
    mutationFn: ({ token, chainId }: { token: Token; chainId: number }) =>
      mint(token, chainId),
  });
}

/** Pre-flight mint check. Rejects with TokenMintedError / InsufficientBalanceError. */
export function useCheckMintable() {
  return useMutation({
    mutationFn: ({ token, chainId }: { token: Token; chainId: number }) =>
      checkMintable(token, chainId),
  });
}

/** Resolves an ApprovalStatus on demand and mirrors the side-effectful store writes. */
export function useCheckTokenApproval() {
  return useMutation({
    mutationFn: (token: Maybe<Token | NFT>) => getTokenApprovalStatus(token),
  });
}

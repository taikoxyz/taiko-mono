# Optaiko

> A clean-room implementation of a Panoptic-style options protocol built on Uniswap V4

## Overview

Optaiko is an options trading protocol that leverages Uniswap V4 liquidity positions to create perpetual options with streaming premia. Unlike traditional options protocols, Optaiko represents options as positions within Uniswap V4 pools, where:

- **Short options** = Providing liquidity to earn fees (streaming premium)
- **Long options** = Conceptually "borrowing" liquidity (paying streaming premium)


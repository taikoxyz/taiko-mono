## TAIKO Tokenomics

This document outlines the current tokenomics.

- $D_i$: The *i*-th block's proving delay.
- $A_i$: The average block proving delay after the *i*-th block.

We have: 
$$A_i = {63 A_{i-1} + D_i \over 64}$$

- $B$: a fix amount of gas per block.
- $L_i$: The block gas limit for the *i*-th block.


- $F_i$: The proposer fee for the *i*-th block.
- $\hat{F_i}$: The discouted proposer fee for the *i*-th block, $\hat{F_i} = 0.95F_i$
- $g_i$: The gas price after the *i*-th block is finalized.

We have (1559-style):

$$ g_i = {{g_{i-1} (31 R_{i-1} + F_{i-1})} \over {32 R_{i-1}}} $$



- $\hat{g_i}$: It is $g_i$ adjusted based on the number of pending blocks, the more pending blocks, the bigger $\hat{g_i}$ will be, compared with $g_i$.


We have: 
$$F_i = \hat{g_{i-1}} (B+L_i) $$

- $R_i$: The prover fee for the *i*-th block.

- $R_i(t)$: The prover fee for the *i*-th block if the block is proven with a delay of $t$.

    - if $t <= A_{i-1}$ then $R_i(t)=\hat{F_i}$
    - else $R_i(t)=   max( 100 * \hat{F_i},   ({1 \over 2}  + {t \over A_{i-1}})\hat{F_i} ) $




<img width="80%" alt="Screenshot 2022-08-09 at 19 29 51" src="https://user-images.githubusercontent.com/99078276/183636828-1e61f975-8b9d-4fe3-b014-90f90e25a283.png">


Currently we allow up to 5 proofs per block. If the first proof was submitted with delay $D^1$, all the other *uncle proofs* must be submitted within a time window of $D^1 \over 2$.

Each uncle proof will earn a return of $R \over 10$, all the rest goes to the first prover. This means the first prover will get 60%-100% of the prover fee.

from present import Config, Timing, Present

present = Present(
    title="p8: 0 fee/reward but non-zero prover bootstrap reward with constant block time",
    desc="""

**What to simulate?**

Give prover per-block bootstrap reward based on the current block time average.

**About this config**
Block `fee_base` is set to 0.

""",
    days=12,
    config=Config(
        max_blocks=2048, 
        lamda=590,
        fee_base=0.0,
        fee_maf=1024,
        reward_multiplier=4.0,
        # prover_reward_burn_points=0.0,
        # prover_reward_bootstrap=1000000.0,
        # prover_reward_bootstrap_days=10,
        time_avg_maf=1024,
        block_time_sd_pctg=0,
        proof_time_sd_pctg=0,
        timing=[
            Timing(
                block_time_avg_second=15,
                proof_time_avg_minute=45,
            ),
        ],
    ),
)

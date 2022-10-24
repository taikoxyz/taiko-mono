from present import Config, Timing, Present

present = Present(
    title="p9: 0 fee/reward but non-zero prover bootstrap reward with block time variation",
    desc="""

**What to simulate?**

Give prover per-block bootstrap reward based on the current block time average.

**About this config**
Block `fee_base` is set to 0.

""",
    days=12,
    config=Config(
        max_slots=10000000,
        lamda_ratio=100000,
        fee_base=0.0,
        fee_base_maf=1024,
        block_fee_min_ratio=0.5,
        prover_reward_min_ratio=0.5,
        prover_reward_max_ratio=2.0,
        prover_reward_tax_pctg=0.0,
        prover_reward_bootstrap=1000000.0,
        prover_reward_bootstrap_day=8,
        block_and_proof_time_maf=1024,
        timing=[
            Timing(
                block_time_avg_second=15,
                block_time_sd_pctg=100,
                proof_time_avg_minute=45,
                proof_time_sd_pctg=0,
            ),
            Timing(
                block_time_avg_second=35,
                block_time_sd_pctg=100,
                proof_time_avg_minute=45,
                proof_time_sd_pctg=0,
            ),
            Timing(
                block_time_avg_second=55,
                block_time_sd_pctg=100,
                proof_time_avg_minute=45,
                proof_time_sd_pctg=0,
            ),
            Timing(
                block_time_avg_second=15,
                block_time_sd_pctg=100,
                proof_time_avg_minute=45,
                proof_time_sd_pctg=0,
            ),
        ],
    ),
)

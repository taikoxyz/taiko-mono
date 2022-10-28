from present import Config, Timing, Present

present = Present(
    title="p0: constant block time and proof time",
    desc="""

**What to simulate?**

The most basic model where block time and proof time are both constant.

**About this config**

Block (proposal) fee is constant. This is achieved by settting `max_blocks` and
`lamda_ratio` to large values and `block_time_sd_pctg` to 0.
""",
    days=7,
    config=Config(
        max_blocks=2048, 
        lamda=2048,
        base_fee=100.0,
        base_fee_maf=1024,
        block_fee_min_ratio=0.5,
        prover_reward_max_ratio=2.0,
        prover_reward_burn_points=0.0,
        prover_reward_bootstrap=0,
        prover_reward_bootstrap_day=10,
        block_and_proof_time_maf=1024,
        timing=[
            Timing(
                block_time_avg_second=15,
                block_time_sd_pctg=0,
                proof_time_avg_minute=45,
                proof_time_sd_pctg=0,
            ),
        ],
    ),
)

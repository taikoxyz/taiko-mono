from present import Config, Timing, Present

present = Present(
    title="p0: constant block time and proof time",
    desc="""

**What to simulate?**

The most basic model where block time and proof time are both constant.

**About this config**

Block fee is constant. This is achieved by settting `max_blocks` and
`lamda_ratio` to large values and `block_time_sd_pctg` to 0.
""",
    days=20,
    config=Config(
        max_blocks=2048, 
        lamda=2048,
        fee_avg=100.0,
        fee_maf=1024,
        fee_multiplier=4.0,
        # prover_reward_burn_points=0.0,
        # prover_reward_bootstrap=0,
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

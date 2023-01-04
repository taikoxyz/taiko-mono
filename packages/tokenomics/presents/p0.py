from present import Config, Timing, Present

present = Present(
    title="p0: block time and proof time both constant",
    desc="""

**What to simulate?**

The most basic model where the block time average and proof time average are both constant.

**About this config**

- TKO supply changes initially but stablizes.
- fee_base remains constant

""",
    days=7,
    config=Config(
        max_blocks=2048, 
        lamda=590,
        fee_base=100.0,
        fee_maf=1024,
        reward_multiplier=4.0,
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

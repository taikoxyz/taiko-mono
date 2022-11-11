from present import Config, Timing, Present

present = Present(
    title="p4: varying block time, varying proof time",
    desc="""

**What to verify**
- block fee stays constant.
- proof reward adapts to proof time changes.
- total supply change stablizes.


""",
    days=10,
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
            Timing(
                block_time_avg_second=15,
                proof_time_avg_minute=25,
            ),
            Timing(
                block_time_avg_second=15,
                proof_time_avg_minute=15,
            ),
            Timing(
                block_time_avg_second=15,
                proof_time_avg_minute=45,
            ),
        ],
    ),
)

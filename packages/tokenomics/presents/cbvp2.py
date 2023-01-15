from present import Config, Timing, Present

present = Present(
    title="cbvp2: constant block time, proof time goes up, down, then restores",
    desc="""

**About this config**

- the block time average set to a constant.
- the proof time average varies but eventually changes back to the initial value.

**What to verify**
- fee_base will become smaller if proof time becomes larger.
- fee_base remains the same if proof time becomes smaller.

""",
    days=21,
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
                proof_time_avg_minute=45*1.3,
            ),
            Timing(
                block_time_avg_second=15,
                proof_time_avg_minute=45*1.3*1.3,
            ),
            Timing(
                block_time_avg_second=15,
                proof_time_avg_minute=45*1.3,
            ),
            Timing(
                block_time_avg_second=15,
                proof_time_avg_minute=45,
            ),
            Timing(
                block_time_avg_second=15,
                proof_time_avg_minute=45/1.3,
            ),
            Timing(
                block_time_avg_second=15,
                proof_time_avg_minute=45/1.3/1.3,
            ),
            Timing(
                block_time_avg_second=15,
                proof_time_avg_minute=45/1.3,
            ),
            Timing(
                block_time_avg_second=15,
                proof_time_avg_minute=45,
            ),
        ],
    ),
)

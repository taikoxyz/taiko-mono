from present import Config, Timing, Present

present = Present(
    title="p10: TKO token price goes up",
    desc="""

**What to simulate?**

Whe TKO's price goes up, the block time will become logger to reduce the base fee, then
the block time will recover, but the base fee remains lower than before.


""",
    days=10,
    config=Config(
        max_blocks=2048, 
        lamda=2048,
        base_fee=100.0,
        base_fee_maf=1024,
        fee_max_multiplier=4.0,
        # prover_reward_burn_points=0.0,
        # prover_reward_bootstrap=0.0,
        # prover_reward_bootstrap_days=0,
        block_and_proof_time_maf=1024,
        block_time_sd_pctg=0,
        proof_time_sd_pctg=0,
        timing=[
            Timing(
                block_time_avg_second=15,
                proof_time_avg_minute=45,
            ),
            Timing(
                block_time_avg_second=35,
                proof_time_avg_minute=45,
            ),
            Timing(
                block_time_avg_second=15,
                proof_time_avg_minute=45,
            ),
            Timing(
                block_time_avg_second=15,
                proof_time_avg_minute=45,
            ),
        ],
    ),
)

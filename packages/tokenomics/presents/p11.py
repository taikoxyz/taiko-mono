from present import Config, Timing, Present

present = Present(
    title="p11: TKO token price goes down",
    desc="""

**What to simulate?**

Whe TKO's price goes down, the proof time will become logger to increase the base fee, then
the proof time willp10: TKO token goes down
 recover, but the base fee remains higher than before.


""",
    days=20,
    config=Config(
        max_blocks=2048, 
        lamda=2048,
        fee_avg=100.0,
        fee_maf=1024,
        fee_multiplier=4.0,
        # prover_reward_burn_points=0.0,
        # prover_reward_bootstrap=0.0,
        # prover_reward_bootstrap_days=0,
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
                proof_time_avg_minute=45,
            ),
            Timing(
                block_time_avg_second=15,
                proof_time_avg_minute=80,
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

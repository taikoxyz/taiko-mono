from present import Config, Timing, Present

present = Present(
    title="p11: TKO token goes down",
    desc="""

**What to simulate?**

Whe TKO's price goes down, the proof time will become logger to increase the base fee, then
the proof time willp10: TKO token goes down
 recover, but the base fee remains higher than before.


""",
    days=20,
    config=Config(
        max_slots=2048, 
        lamda=2048,
        base_fee=100.0,
        base_fee_maf=1024,
        block_fee_min_ratio=0.5,
        prover_reward_max_ratio=2.0,
        prover_reward_burn_points=0.0,
        prover_reward_bootstrap=0.0,
        prover_reward_bootstrap_day=0,
        block_and_proof_time_maf=1024,
        timing=[
            Timing(
                block_time_avg_second=15,
                block_time_sd_pctg=0,
                proof_time_avg_minute=45,
                proof_time_sd_pctg=10,
            ),
            Timing(
                block_time_avg_second=15,
                block_time_sd_pctg=0,
                proof_time_avg_minute=45,
                proof_time_sd_pctg=10,
            ),
            Timing(
                block_time_avg_second=15,
                block_time_sd_pctg=0,
                proof_time_avg_minute=80,
                proof_time_sd_pctg=10,
            ),
            Timing(
                block_time_avg_second=15,
                block_time_sd_pctg=0,
                proof_time_avg_minute=45,
                proof_time_sd_pctg=10,
            ),
            Timing(
                block_time_avg_second=15,
                block_time_sd_pctg=0,
                proof_time_avg_minute=45,
                proof_time_sd_pctg=10,
            ),
        ],
    ),
)

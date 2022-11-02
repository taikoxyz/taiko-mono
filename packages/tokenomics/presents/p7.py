from present import Config, Timing, Present

present = Present(
    title="p7: provers joined Taiko then left",
    desc="""

**About this config**

- slot fee now varies
- `# prover_reward_burn_points` set to non-zero
- block time varies (100%  ocsliaction) but eventually changes back to the initial value.
- proof time varies (100%  ocsliaction) but eventually changes back to the initial value.

**What to verify**
- proof reward adapts to proof time changes.

""",
    days=20,
    config=Config(
        max_blocks=2048, 
        lamda=2048,
        incentive=100.0,
        incentive_maf=1024,
        incentive_multiplier=4.0,
        # prover_reward_burn_points=100,
        # prover_reward_bootstrap=0,
        # prover_reward_bootstrap_days=10,
        time_maf=1024,
        block_time_sd_pctg=0,
        proof_time_sd_pctg=0,
        timing=[
            Timing(
                block_time_avg_second=15,
                proof_time_avg_minute=15,
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
            Timing(
                block_time_avg_second=15,
                proof_time_avg_minute=35,
            ),
            Timing(
                block_time_avg_second=15,
                proof_time_avg_minute=25,
            ),
            Timing(
                block_time_avg_second=15,
                proof_time_avg_minute=15,
            ),
        ],
    ),
)

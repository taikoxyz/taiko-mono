from present import Config, Timing, Present

present = Present(
    title="p3: constant block time, varying proof time (200% ocsliaction)",
    desc="""

**About this config**

- block time set to a constant (no ocsliaction).
- proof time varies (200%  ocsliaction) but eventually changes back to the initial value.

**What to verify**
- block fee stays constant.
- proof reward adapts to proof time changes.
- total supply change stablizes.


""",
    days=10,
    config=Config(
        max_slots=10000000,
        lamda_ratio=100000,
        fee_base=100.0,
        fee_base_maf=1024,
        block_fee_min_ratio=0.5,
        prover_reward_min_ratio=0.5,
        prover_reward_max_ratio=4.0,
        prover_reward_tax_pctg=0.0,
        prover_reward_bootstrap=0,
        prover_reward_bootstrap_day=10,
        block_and_proof_time_maf=1024,
        timing=[
            Timing(
                block_time_avg_second=15,
                block_time_sd_pctg=0,
                proof_time_avg_minute=45,
                proof_time_sd_pctg=200,
            ),
            Timing(
                block_time_avg_second=15,
                block_time_sd_pctg=0,
                proof_time_avg_minute=25,
                proof_time_sd_pctg=200,
            ),
            Timing(
                block_time_avg_second=15,
                block_time_sd_pctg=0,
                proof_time_avg_minute=15,
                proof_time_sd_pctg=200,
            ),
            Timing(
                block_time_avg_second=15,
                block_time_sd_pctg=0,
                proof_time_avg_minute=45,
                proof_time_sd_pctg=200,
            ),
        ],
    ),
)

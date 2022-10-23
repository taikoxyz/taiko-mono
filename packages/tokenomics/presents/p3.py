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
        base_fee=100.0,
        base_fee_maf=1024,
        reward_min_ratio=0.5,
        reward_max_ratio=4.0,
        reward_tax_pctg=0.0,
        reward_bootstrap=0,
        reward_bootstrap_month=24,
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

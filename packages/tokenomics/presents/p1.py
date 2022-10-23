from present import Config, Timing, Present

present = Present(
    title="p1: constant block time, varying proof time (no ocsliaction)",
    desc="""

**About this config**

- block time set to a constant (no ocsliaction).
- proof time varies (no ocsliaction) but eventually changes back to the initial value.

**What to verify**
- block fee stays constant.
- proof reward adapts to proof time changes.
- total supply change stablizes.


""",
    days=7,
    config=Config(
        max_slots=10000000,
        lamda_ratio=100000,
        base_fee=100.0,
        base_fee_maf=1024,
        reward_min_ratio=0.5,
        reward_max_ratio=2.0,
        reward_tax_pctg=0.0,
        reward_bootstrap=0,
        reward_bootstrap_month=24,
        block_and_proof_time_maf=1024,
        timing=[
            Timing(
                block_time_avg_second=15,
                block_time_sd_pctg=0,
                proof_time_avg_minute=45,
                proof_time_sd_pctg=0,
            ),
            Timing(
                block_time_avg_second=15,
                block_time_sd_pctg=0,
                proof_time_avg_minute=25,
                proof_time_sd_pctg=0,
            ),
            Timing(
                block_time_avg_second=15,
                block_time_sd_pctg=0,
                proof_time_avg_minute=15,
                proof_time_sd_pctg=0,
            ),
            Timing(
                block_time_avg_second=15,
                block_time_sd_pctg=0,
                proof_time_avg_minute=45,
                proof_time_sd_pctg=0,
            ),
        ],
    ),
)

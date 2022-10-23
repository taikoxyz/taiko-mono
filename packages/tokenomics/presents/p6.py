from present import Config, Timing, Present

present = Present(
    title="p6: varying block time (100% ocsliaction), varying proof time (100% ocsliaction), with slot fees",
    desc="""

**About this config**

- slot fee now varies
- `reward_tax_pctg` set to non-zero
- block time varies (100%  ocsliaction) but eventually changes back to the initial value.
- proof time varies (100%  ocsliaction) but eventually changes back to the initial value.

**What to verify**
- block fee stays constant.
- proof reward adapts to proof time changes.
- total supply decrease.

""",
    days=20,
    config=Config(
        max_slots=2400,
        lamda_ratio=1,
        base_fee=100.0,
        base_fee_maf=1024,
        reward_min_ratio=0.5,
        reward_max_ratio=4.0,
        reward_tax_pctg=0.5,
        block_and_proof_time_maf=1024,
        timing=[
            Timing(
                block_time_avg_second=15,
                block_time_sd_pctg=100,
                proof_time_avg_minute=45,
                proof_time_sd_pctg=100,
            ),
            Timing(
                block_time_avg_second=25,
                block_time_sd_pctg=100,
                proof_time_avg_minute=25,
                proof_time_sd_pctg=100,
            ),
            Timing(
                block_time_avg_second=8,
                block_time_sd_pctg=100,
                proof_time_avg_minute=15,
                proof_time_sd_pctg=100,
            ),
            Timing(
                block_time_avg_second=15,
                block_time_sd_pctg=100,
                proof_time_avg_minute=45,
                proof_time_sd_pctg=100,
            ),
        ],
    ),
)

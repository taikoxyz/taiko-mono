from present import Config, Timing, Present

present = Present(
    title="p7: provers joined Taiko then left",
    desc="""

**About this config**

- slot fee now varies
- `prover_reward_tax_pctg` set to non-zero
- block time varies (100%  ocsliaction) but eventually changes back to the initial value.
- proof time varies (100%  ocsliaction) but eventually changes back to the initial value.

**What to verify**
- proof reward adapts to proof time changes.

""",
    days=20,
    config=Config(
        max_slots=1024, 
        lamda_ratio=1.2,
        fee_base=100.0,
        fee_base_maf=1024,
        block_fee_min_ratio=0.5,
        prover_reward_max_ratio=4.0,
        prover_reward_tax_pctg=0.5,
        prover_reward_bootstrap=0,
        prover_reward_bootstrap_day=10,
        block_and_proof_time_maf=1024,
        timing=[
            Timing(
                block_time_avg_second=15,
                block_time_sd_pctg=100,
                proof_time_avg_minute=15,
                proof_time_sd_pctg=100,
            ),
            Timing(
                block_time_avg_second=15,
                block_time_sd_pctg=100,
                proof_time_avg_minute=25,
                proof_time_sd_pctg=100,
            ),
            Timing(
                block_time_avg_second=15,
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
            Timing(
                block_time_avg_second=15,
                block_time_sd_pctg=100,
                proof_time_avg_minute=35,
                proof_time_sd_pctg=100,
            ),
            Timing(
                block_time_avg_second=15,
                block_time_sd_pctg=100,
                proof_time_avg_minute=25,
                proof_time_sd_pctg=100,
            ),
            Timing(
                block_time_avg_second=15,
                block_time_sd_pctg=100,
                proof_time_avg_minute=15,
                proof_time_sd_pctg=100,
            ),
        ],
    ),
)

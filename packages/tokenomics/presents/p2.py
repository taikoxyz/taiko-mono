from present import Config, Timing, Present

present = Present(
    title="p2: another present example",
    desc="some description can go here",
    days=10,
    config=Config(
        max_slots=1000,
        lamda_ratio=1,
        base_fee=10.0,
        base_fee_maf=1024,
        reward_min_ratio=0.5,
        reward_max_ratio=2.0,
        block_and_proof_time_maf=1024,
        timing=[
            Timing(
                block_time_avg_second=15,
                block_time_sd_pctg=0,
                proof_time_avg_minute=45,
                proof_time_sd_pctg=0,
            )
        ],
    ),
)

from present import Config, Timing, Present

present = Present(
    title="p2-abc111",
    desc="xyz111",
    config=Config(
        max_slots=1000,
        lamda_ratio=1,
        base_fee=10.0,
        base_fee_smoothing=1024,
        block_and_proof_smoothing=1024,
        timing=[
            Timing(
                block_time_avg_second=15,
                block_time_sd_pctg=0,
                proof_time_avg_minute=45,
                proof_time_sd_pctg=0)]
    )
)

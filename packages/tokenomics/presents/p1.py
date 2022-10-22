from present import SimConfig, Present


present = Present(
    title="abc",
    desc="xyz",
    config=SimConfig(
        duration_days=5,
        max_slots=1,
        lamda_ratio=1,
        base_fee=10.0,
        base_fee_smoothing=512,
        block_and_proof_smoothing=1024,
        block_time_avg_second=10,
        block_time_sd_ptcg=0,
        proof_time_avg_minute=45,
        proof_time_sd_pctg=10,
    ),
)

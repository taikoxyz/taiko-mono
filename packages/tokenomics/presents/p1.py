from present import Config, Timing, Present

present = Present(
    title="p1: proof-time normal oscillation has no impact on total mint",
    desc="""
We'd like to know how the proving reward changes while the proving time
oscillates around its moving average by less than 100%. `max_slots` and
`lamda_ratio` are set to be very big values so the slot fee is almost
constant regardless of the number of pending blocks. This enables us to
verify how proving reward is affected by the block's proving delay.

We should be able to verify:
- the total mint of new tokens shall stay the same after a while.
- if `proof_time_sd_pctg` is changed to 0, the proving rewards shall be exactly be the same as the proposing fees.
""",
    config=Config(
        max_slots=10000000,
        lamda_ratio=100000,
        base_fee=100.0,
        base_fee_smoothing=1024,
        block_and_proof_smoothing=1024,
        timing=[
            Timing(
                block_time_avg_second=15,
                block_time_sd_pctg=0,
                proof_time_avg_minute=45,
                proof_time_sd_pctg=0),
            Timing(
                block_time_avg_second=15,
                block_time_sd_pctg=0,
                proof_time_avg_minute=45,
                proof_time_sd_pctg=10),
            Timing(
                block_time_avg_second=15,
                block_time_sd_pctg=0,
                proof_time_avg_minute=25,
                proof_time_sd_pctg=0)]
    ),
)

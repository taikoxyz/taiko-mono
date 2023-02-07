import math


if __name__ == "__main__":
    print("Expected block time (seconds)", end=": ")
    block_time = int(input())

    print("Expected proof time (minutes)", end=": ")
    proof_time = int(input()) * 60

    print("Slot availability multiplier", end=": ")
    slot_availability_multiplier = int(input())
    if slot_availability_multiplier <= 5:
        print("error: Slot availability multiplier must be greater than 5")
        exit(1)

    print("Number of ZKPs required per block before verificaiton", end=": ")
    zk_proofs_per_block = int(input())

    if zk_proofs_per_block < 1 or zk_proofs_per_block > 5:
        print("error: Number of ZKPs must be between 1 and 5")
        exit(1)

    if zk_proofs_per_block == 1:
        min_num_slots = math.ceil(1.0 * proof_time / block_time)
        initial_uncle_delay = proof_time
    else:
        print("Inital uncle proof delay (minutes)", end=": ")
        initial_uncle_delay = int(input()) * 60
        min_num_slots = math.ceil(1.0 * (proof_time + initial_uncle_delay) / block_time)

    print("Extra slots (e.g, 50 means 50% more slots)", end=": ")
    extra_slots = int(input())

    print("---------")

    print("min num slots:", min_num_slots)
    max_num_slots = min_num_slots + math.ceil(min_num_slots * extra_slots / 100) + 1

    k = slot_availability_multiplier
    n = max_num_slots

    # https://www.wolframalpha.com/input?i=solve++%28n%2Bx%29%28n%2Bx-1%29%3Dk*%281%2Bx%29x+for+x
    fee_smoothing_factor = (
        k - 2 * n + 1 - math.sqrt(k * (k + 4 * n * n - 8 * n + 2) + 1.0)
    ) / (2 - 2 * k)

    fee_smoothing_factor = int(fee_smoothing_factor * 1000)

    # f = fee_smoothing_factor
    # print(1.0*(f+n*1000)*(f+n*1000-1000)/((f+1000)*f))

    print("---------")
    print("initialUncleDelay:", int(initial_uncle_delay / 60), "minutes")
    print("maxNumBlocks:", max_num_slots)
    print("zkProofsPerBlock:", zk_proofs_per_block)
    print("slotSmoothingFactor:", fee_smoothing_factor)

import math


if __name__ == "__main__":
    print("Expected block time (seconds)", end=": ")
    block_time = int(input())

    print("Expected proof time (minutes)", end=": ")
    proof_time = int(input()) * 60

    print("Max baseFee upside (5 = 5x)", end=": ")
    max_basefee_upside = int(input())
    if max_basefee_upside < 5:
        print("error: Max baseFee upside < 5")
        exit(1)

    min_num_slots = math.ceil(1.0 * proof_time / block_time)

    print("Extra slots (e.g, 50 means 50% more slots)", end=": ")
    extra_slots = int(input())

    print("---------")

    print("min num slots:", min_num_slots)
    max_num_slots = min_num_slots + math.ceil(min_num_slots * extra_slots / 100) + 1

    k = max_basefee_upside
    n = max_num_slots

    # https://www.wolframalpha.com/input?i=solve++%28n%2Bx%29%28n%2Bx-1%29%3Dk*%281%2Bx%29x+for+x
    fee_smoothing_factor = (
        k - 2 * n + 1 - math.sqrt(k * (k + 4 * n * n - 8 * n + 2) + 1.0)
    ) / (2 - 2 * k)

    fee_smoothing_factor = int(fee_smoothing_factor * 1000)

    # f = fee_smoothing_factor
    # print(1.0*(f+n*1000)*(f+n*1000-1000)/((f+1000)*f))

    print("---------")
    print("maxNumProposedBlocks:", max_num_slots)

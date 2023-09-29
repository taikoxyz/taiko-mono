"""
This Python program generates a Solidity library file (data.sol) containing a function named `data()`.
The function returns a two-dimensional uint32 array with dimensions 2x100.

The array's elements are generated based on two different normal distributions for each sub-array [blockDelay, parentGasUsed]:

1. The first element 'blockDelay' is based on a mixed normal distribution with:
    - 95% of the values following a normal distribution centered around 3
    - 5% of the values following a normal distribution centered around 100

2. The second element 'parentGasUsed' follows a normal distribution centered around 4,300,000.

Each sub-array [blockDelay, parentGasUsed] is a sample, and there are 100 such samples in the array.

Note: Negative values for 'blockDelay' are avoided by taking the absolute value of the generated sample.

The generated Solidity library file (test/L2/Lib1559MathTest.d.sol) contains the `data()` function, which initializes the two-dimensional array in memory and assigns each element individually based on the generated values.
"""

import numpy as np
import time

# Number of samples
n = 400

# Medians and proportions
median1 = 3
median2 = 100
prop1 = 0.95
prop2 = 0.05

# Initialize list to store samples
samples1 = []

# Generate random numbers
# Seed the random number generator
np.random.seed(int(time.time()))
for _ in range(n):
    selector = np.random.uniform(0, 1)
    if selector < prop1:
        sample = abs(np.random.normal(median1, 1))
    else:
        sample = abs(np.random.normal(median2, 10))
    samples1.append(sample)

# Generate the second set of samples
samples2 = np.random.normal(4300000, 100000, n)

# Combine samples into pairs and round to integers
pairs = [(int(round(a)), int(round(b))) for a, b in zip(samples1, samples2)]

# Generate Solidity assignment statements
assignments = "\n".join([f"_blocks[{i}][0] = {a}; _blocks[{i}][1] = {b};" for i, (a, b) in enumerate(pairs)])

# Write to a Solidity file
with open("test/L2/Lib1559MathTest.d.sol", "w") as f:
    f.write("pragma solidity ^0.8.0;\n\n")
    f.write("library Lib1559MathTestData {\n")
    f.write(f"function blocks() public pure returns (uint32[2][] memory _blocks)")
    f.write("{\n")
    f.write(f"_blocks = new uint32[2][]({n});")
    f.write(assignments)
    f.write("\n}\n")
    f.write("}\n")

print("Lib1559MathTest.d.sol file has been generated.")

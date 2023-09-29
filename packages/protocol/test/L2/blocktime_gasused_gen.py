import numpy as np

# Number of samples
n = 100

# Medians and proportions
median1 = 3
median2 = 100
prop1 = 0.95
prop2 = 0.05

# Initialize list to store samples
samples1 = []

# Generate random numbers
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
assignments = "\n".join([f"       _blocks[{i}][0] = {a}; _blocks[{i}][1] = {b};" for i, (a, b) in enumerate(pairs)])

# Write to a Solidity file
with open("test/L2/Lib1559MathTest.d.sol", "w") as f:
    f.write("pragma solidity ^0.8.0;\n\n")
    f.write("library Lib1559MathTestData {\n")
    f.write(f"   function blocks() public pure returns (uint32[2][{n}] memory _blocks)")
    f.write("{\n")
    f.write(assignments)
    f.write("\n   }\n")
    f.write("}\n")

print("Lib1559MathTest.d.sol file has been generated.")

import argparse
import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path

HIGH_TRAFFIC_STARTS = "HIGH TRAFFIC STARTS"
HIGH_TRAFFIC_ENDS = "HIGH TRAFFIC ENDS"
LOW_TRAFFIC_STARTS = "LOW TRAFFIC STARTS"
LOW_TRAFFIC_ENDS = "LOW TRAFFIC ENDS"
TARGET_TRAFFIC_STARTS = "TARGET TRAFFIC STARTS"
TARGET_TRAFFIC_ENDS = "TARGET TRAFFIC ENDS"
INFO = "L2block to baseFee is"
AVERAGE_GAS_USED_PER_L1 = "Average gasUsed per L1 block"
AVERAGE_GAS_PRICE_IN_L2 = "Average wei gas price per L2 block is"
# 0: no parsing ATM
# 1: HIGH
# 2: LOW
# 3: TARGET
PARSER_MODE = 1

# Average proposal time
AVG_BASEFEE_PER_L2_BLOCK = 0
# Average proof time
AVG_GAS_USED_PER_L1_BLOCK = 0


def percentage_deviation(initial, final):
    deviation = final - initial
    percentage_deviation = (deviation / initial) * 100
    return round(percentage_deviation, 1)


def label_text():
    global AVG_BASEFEE_PER_L2_BLOCK, AVG_GAS_USED_PER_L1_BLOCK
    return "Avg basefee / L2 block:{:.2f} gwei    Avg. gas per L1 block (12s):{:.2f} million".format(
        AVG_BASEFEE_PER_L2_BLOCK, AVG_GAS_USED_PER_L1_BLOCK
    )


def save_plots(
    x_axis,
    y_axis,
    filename,
    title,
    x_label,
    y_label,
    y_signal_label,
    y2_signal_label=None,
    y2_axis=None,
):
    fig = plt.figure(figsize=(10, 6))
    fig.text(
        0.1,
        0.96,
        label_text(),
        fontsize=10,
        style="italic",
        bbox={"facecolor": "green", "alpha": 0.4, "pad": 1},
    )
    xpoints = np.array(x_axis)
    ypoints = np.array(y_axis)

    plt.title(title)
    plt.xlabel(x_label)
    plt.ylabel(y_label)

    plt.plot(xpoints, ypoints, "r", label=y_signal_label)
    if y2_axis is not None:
        y2points = np.array(y2_axis)
        plt.plot(xpoints, y2points, "b", label=y2_signal_label)
    plt.legend()
    plt.savefig(filename)


def parse_and_plot(filename):
    global PARSER_MODE, AVG_BASEFEE_PER_L2_BLOCK, AVG_GAS_USED_PER_L1_BLOCK, AVERAGE_GAS_USED_PER_L1, AVERAGE_GAS_PRICE_IN_L2

    only_stem = Path(filename).stem
    timestamp = only_stem.split("_")[1]
    # First part
    x_ax_block_nr = []
    y_ax_base_fee = []
    with open(filename) as file:
        for line in file:

            if HIGH_TRAFFIC_STARTS in line:
                PARSER_MODE = 1
                continue

            if HIGH_TRAFFIC_ENDS in line:
                # Saving the first plot
                x_axis = x_ax_block_nr
                y_axis = y_ax_base_fee
                filename = "out/{}_above_average_traffic.png".format(timestamp)
                title = "Basefee chart per L2 block (if gas used above target)"
                y_label = "baseFee"
                x_label = "L2 block count"
                y_signal_label = "basefee in gwei"
                save_plots(
                    x_axis, y_axis, filename, title, x_label, y_label, y_signal_label
                )
                x_ax_block_nr = []
                y_ax_base_fee = []
                PARSER_MODE = 0
                continue

            if LOW_TRAFFIC_STARTS in line:
                PARSER_MODE = 2
                continue

            if LOW_TRAFFIC_ENDS in line:
                # Saving the first plot
                x_axis = x_ax_block_nr
                y_axis = y_ax_base_fee
                filename = "out/{}_below_average_traffic.png".format(timestamp)
                title = "Basefee chart per L2 block (if gas used below target)"
                y_label = "baseFee"
                x_label = "L2 block count"
                y_signal_label = "basefee in gwei"
                save_plots(
                    x_axis, y_axis, filename, title, x_label, y_label, y_signal_label
                )
                x_ax_block_nr = []
                y_ax_base_fee = []
                PARSER_MODE = 0
                continue

            if TARGET_TRAFFIC_STARTS in line:
                PARSER_MODE = 3
                continue

            if TARGET_TRAFFIC_ENDS in line:
                # Saving the first plot
                x_axis = x_ax_block_nr
                y_axis = y_ax_base_fee
                filename = "out/{}_target_traffic.png".format(timestamp)
                title = "Basefee chart per L2 block (if gas used around target)"
                y_label = "baseFee"
                x_label = "L2 block count"
                y_signal_label = "basefee in gwei"
                save_plots(
                    x_axis, y_axis, filename, title, x_label, y_label, y_signal_label
                )
                x_ax_block_nr = []
                y_ax_base_fee = []
                PARSER_MODE = 0
                continue

            if INFO in line and PARSER_MODE != 0:
                data = line.rstrip().split(":")
                x_ax_block_nr.append(float(data[1]))
                y_ax_base_fee.append(float(data[2]) / 1000000000)
                continue

            if AVERAGE_GAS_USED_PER_L1 in line:
                data = line.rstrip().split(":")
                AVG_GAS_USED_PER_L1_BLOCK = float(data[1]) / 1000000
                continue

            if AVERAGE_GAS_PRICE_IN_L2 in line:
                data = line.rstrip().split(":")
                AVG_BASEFEE_PER_L2_BLOCK = float(data[1]) / 1000000000
                continue


def parse_args():
    parser = argparse.ArgumentParser(description="Parsed filename")
    parser.add_argument("file", type=str)
    args = parser.parse_args()
    return args


def main():
    inputs = parse_args()
    parse_and_plot(inputs.file)


if __name__ == "__main__":
    main()

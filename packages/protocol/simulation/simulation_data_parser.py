import argparse
import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path

PLOT_PROOF_PER_BLOCK_START_PATTERN = 'BlockId, ProofTime'
PLOT_PROOF_PER_BLOCK_END_PATTERN = 'Last second:'
PROOF_TIME_TARGET_PATTERN = 'Proof time target'
AVG_PROP_TIME_PATTERN = 'Average proposal time'
AVG_PROVE_TIME_PATTERN = 'Average proof time'
MAIN_START_PATTERN = '!-----------------------------'
MAIN_END_PATTERN = '-----------------------------!'

# 0: no parsing ATM - just the lines
# 1: parsing data for plotting proof time / block
# 2: parsing data for the 'main' plotting (fee calc)
PARSER_MODE = 0 

# Last blocks proposed timestamp
LAST_BLOCK_TS = 0
# Average propsal time
AVG_PROP_TIME = 0
# Average proof time
AVG_PROOF_TIME = 0
# Proof time target
PROOF_TIME_TARGET = 0

def percentage_deviation(initial, final):
    deviation = final - initial
    percentage_deviation = (deviation / initial) * 100
    return round(percentage_deviation, 1)

def label_text():
    return "Avg prop time:{}s    Avg. prove time:{}s    Target proof time:{}s    Deviation(target vs. avg): {}% ".format(AVG_PROP_TIME, AVG_PROOF_TIME, PROOF_TIME_TARGET, percentage_deviation(PROOF_TIME_TARGET, AVG_PROOF_TIME))

def save_plots(x_axis, y_axis, filename, title, x_label, y_label, y_signal_label, y2_signal_label=None, y2_axis=None):
    fig = plt.figure(figsize=(10, 6))
    fig.text(.1,.96,label_text(),  fontsize=10, style='italic', bbox={
    'facecolor': 'green', 'alpha': 0.4, 'pad': 1})
    xpoints = np.array(x_axis)
    ypoints = np.array(y_axis)
    
    plt.title(title)
    plt.xlabel(x_label)
    plt.ylabel(y_label)
    
    plt.plot(xpoints, ypoints, 'r', label=y_signal_label)
    if y2_axis is not None:
        y2points = np.array(y2_axis)
        plt.plot(xpoints, y2points, 'b', label=y2_signal_label)
    plt.legend()
    plt.savefig(filename)
    
def parse_and_plot(filename):
    global PARSER_MODE, LAST_BLOCK_TS, AVG_PROP_TIME, AVG_PROOF_TIME, PROOF_TIME_TARGET

    only_stem = Path(filename).stem
    timestamp = only_stem.split('_')[2]
    # First part
    x_ax_block_nr = []
    y_ax_avg_proof_time = []
    # Second part
    x_ax_block_nr_as_ts = []
    y_ax_all_current_prop_blks = []
    y_ax_all_verified_blocks = []
    y_ax_current_basefee = []
    with open(filename) as file:
        for line in file:
            
            if PLOT_PROOF_PER_BLOCK_START_PATTERN in line:
                PARSER_MODE = 1
                #print("Parsot kezdek")
                continue
            
            if PLOT_PROOF_PER_BLOCK_END_PATTERN in line:
                data = line.rstrip().split(':')
                LAST_BLOCK_TS = int(data[1])
                
                PARSER_MODE = 0
                #print("Parsot fejezek")

                #plt.show()
                continue
            
            if PROOF_TIME_TARGET_PATTERN in line:
                data = line.rstrip().split(':')
                PROOF_TIME_TARGET = int(data[1])
                continue
                        
            if AVG_PROP_TIME_PATTERN in line:
                data = line.rstrip().split(':')
                AVG_PROP_TIME = int(data[1])
                continue
                        
            if AVG_PROVE_TIME_PATTERN in line:
                data = line.rstrip().split(':')
                AVG_PROOF_TIME = int(data[1])
                

                continue
            
            if MAIN_START_PATTERN in line:
                PARSER_MODE = 2
                #print("Parsot kezdek")
                continue
            
            if MAIN_END_PATTERN in line:
                # Saving all the main plots
                plt.title("Proposed and verified block number over time")
                plt.xlabel("Time (s)")
                plt.ylabel("Proposed and verified block nr")
    
    
                "{}_prop_and_verified_blocks_with_time.png".format(timestamp)
                 # Saving the first plot
                x_axis = x_ax_block_nr
                y_axis = y_ax_avg_proof_time
                filename = "./plots/{}_proof_time_per_block.png".format(timestamp)
                title = "Proof time / block"
                x_label = "BlockId"
                y_label = "Proof time (s)"
                y_signal_label = ("Prooftime / block")
                save_plots(x_axis, y_axis, filename, title, x_label, y_label, y_signal_label)
                
                 # Saving the first plot
                x_axis = x_ax_block_nr_as_ts
                y_axis = y_ax_all_current_prop_blks
                y2_axis = y_ax_all_verified_blocks
                filename = "./plots/{}_prop_and_verified_blocks_with_time.png".format(timestamp)
                title = "Proposed and verified block over time"
                x_label = "Time (s)"
                y_label = "Proposed and verified blocks"
                y_signal_label = "Nr. of proposed blocks"
                y2_signal_label = "Nr. of verified blocks"
                save_plots(x_axis, y_axis, filename, title, x_label, y_label, y_signal_label, y2_signal_label, y2_axis)
                
                # Saving the first plot
                x_axis = x_ax_block_nr_as_ts
                y_axis = y_ax_current_basefee
                filename = "./plots/{}_blockfee_with_time.png".format(timestamp)
                title = "Base fee over time"
                x_label = "Time (s)"
                y_label = "Blockfee"
                y_signal_label = ("Blockfee")
                save_plots(x_axis, y_axis, filename, title, x_label, y_label, y_signal_label)
                
                PARSER_MODE = 0
                continue
            if PARSER_MODE == 1:
                data = line.rstrip().split(';')
                x_ax_block_nr.append(float(data[0]))
                y_ax_avg_proof_time.append(int(data[1]))
                continue
            
            if PARSER_MODE == 2:
                #logCount,time,lastVerifiedBlockId,numBlocks,blockFee,accProposedAt
                data = line.rstrip().split(';')
                x_ax_block_nr_as_ts.append(float(data[1]))
                y_ax_all_current_prop_blks.append(int(data[3]))
                y_ax_all_verified_blocks.append(int(data[2]))
                y_ax_current_basefee.append(int(data[4]))
                continue
                # Parse the next lines - until 
                # print("First plot start marker")      
            #print(line)
    print("Last second is: {}".format(LAST_BLOCK_TS))
    print("Average proposal time is: {}".format(AVG_PROP_TIME))
    print("Average proof time is: {}".format(AVG_PROOF_TIME))
    print("Proof time target is: {}".format(PROOF_TIME_TARGET))

def parse_args():
    parser=argparse.ArgumentParser(description="Parsed filename")
    parser.add_argument("file", type=str)
    args=parser.parse_args()
    return args

def main():
    inputs=parse_args()
    parse_and_plot(inputs.file)
    

if __name__ == '__main__':
    main()
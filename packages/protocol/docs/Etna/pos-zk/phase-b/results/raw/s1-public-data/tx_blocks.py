import sys, json, datetime
sys.path.insert(0,'.')
from rpc import call
URL='https://gateway.tenderly.co/public/mainnet'
for tx in ["0x7576f1179250453948b37648a748aaade28c40b33e358fa0cbe21be6b0368601",
           "0x64875b5b84b41b520551854696c0ce408fb3e0aa2ede604cc95a5919b6140ea7",
           "0x4a761524f4fe9377a63233971eb3ce7b2101832371f19e1f5e0cf126bae0bf7d"]:
    rc = call(URL, 'eth_getTransactionReceipt', [tx])
    blk = call(URL, 'eth_getBlockByNumber', [rc['blockNumber'], False])
    ts = int(blk['timestamp'], 16)
    print(tx)
    print('   block', int(rc['blockNumber'],16), 'status', rc['status'], 'ts', ts, datetime.datetime.utcfromtimestamp(ts).isoformat()+'Z')

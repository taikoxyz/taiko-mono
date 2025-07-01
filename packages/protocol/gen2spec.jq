# Taken from https://github.com/ethereum/hive and modified to support more cases for Ethereum / OP / Taiko networks

# Usage: cat genesis.json | jq --from-file gen2spec.jq > chainspec.json

# Removes all empty keys and values in input.
def remove_empty:
  . | walk(
    if type == "object" then
      with_entries(
        select(
          .value != null and
          .value != "" and
          .value != [] and
          .key != null and
          .key != ""
        )
      )
    else .
    end
  )
;

# Converts number to hex, from https://rosettacode.org/wiki/Non-decimal_radices/Convert#jq
def int_to_hex:
  def stream:
    recurse(if . > 0 then ./16|floor else empty end) | . % 16 ;
  if . == 0 then "0x0"
  else "0x" + ([stream] | reverse | .[1:] | map(if .<10 then 48+. else 87+. end) | implode)
  end
;

# Converts decimal number in string to hex.
def to_hex:
  if . != null and type == "number" then .|int_to_hex else
    if . != null and startswith("0x") then . else
      if (. != null and . != "") then .|tonumber|int_to_hex else . end
    end
  end
;

# Zero-pads hex string.
def infix_zeros_to_length(s;l):
  if . != null then
    (.[0:s])+("0"*(l-(.|length)))+(.[s:l])
  else .
  end
;

# This gives the consensus engine definition for the ethash engine.
def ethash:
  {
    "Ethash": {}
  }
;

# This gives the consensus engine definition for the op engine.
def optimism:
  {
    "Optimism": {
        "params": {
          "regolithTimestamp": .config.cancunTime|to_hex,
          "bedrockBlockNumber": .config.londonBlock|to_hex,
          "canyonTimestamp": .config.shanghaiTime|to_hex,
          "ecotoneTimestamp": .config.cancunTime|to_hex,
          "fjordTimestamp": .config.fjordTime|to_hex,
          "graniteTimestamp": .config.graniteTime|to_hex,
          "holoceneTimestamp": .config.holoceneTime|to_hex,
          "isthmusTimestamp": .config.isthmusTime|to_hex,
          "l1FeeRecipient": "0x420000000000000000000000000000000000001A",
          "l1BlockAddress": "0x4200000000000000000000000000000000000015",
          "canyonBaseFeeChangeDenominator": "250"
        }
    }
  }
;

def taiko:
  {
    "Taiko": {
      "ontakeTransition": .config.ontakeBlock|to_hex,
      "pacayaTransition": .config.pacayaBlock|to_hex,
    }
  }
;

def clique:
  {
    "clique": {
        "params": {
          "period": .config.clique.period,
          "epoch": .config.clique.epoch,
        }
    }
  }
;

{
  "version": "1",
  "engine": (if .config.optimism != null then optimism elif .config.taiko != null then taiko elif .config.clique != null then clique else ethash end),
  "params": {
    # Tangerine Whistle
    "eip150Transition": "0x0",

    # Spurious Dragon
    "eip160Transition": "0x0",
    "eip161abcTransition": "0x0",
    "eip161dTransition": "0x0",
    "eip155Transition": "0x0",
    "maxCodeSizeTransition": "0x0",
    "maxCodeSize": "0x6000",
    "maximumExtraDataSize": "0x20",

    # Byzantium
    "eip140Transition": .config.byzantiumBlock|to_hex,
    "eip211Transition": .config.byzantiumBlock|to_hex,
    "eip214Transition": .config.byzantiumBlock|to_hex,
    "eip658Transition": .config.byzantiumBlock|to_hex,

    # Constantinople
    "eip145Transition": .config.constantinopleBlock|to_hex,
    "eip1014Transition": .config.constantinopleBlock|to_hex,
    "eip1052Transition": .config.constantinopleBlock|to_hex,

    # Petersburg
    "eip1283Transition": .config.petersburgBlock|to_hex,
    "eip1283DisableTransition": .config.petersburgBlock|to_hex,

    # Istanbul
    "eip152Transition": .config.istanbulBlock|to_hex,
    "eip1108Transition": .config.istanbulBlock|to_hex,
    "eip1344Transition": .config.istanbulBlock|to_hex,
    "eip1884Transition": .config.istanbulBlock|to_hex,
    "eip2028Transition": .config.istanbulBlock|to_hex,
    "eip2200Transition": .config.istanbulBlock|to_hex,

    # Berlin
    "eip2565Transition": .config.berlinBlock|to_hex,
    "eip2718Transition": .config.berlinBlock|to_hex,
    "eip2929Transition": .config.berlinBlock|to_hex,
    "eip2930Transition": .config.berlinBlock|to_hex,

    # London
    "eip1559Transition": .config.londonBlock|to_hex,
    "eip1559ElasticityMultiplier": .config.optimism.eip1559Elasticity|to_hex,
    "eip1559BaseFeeMaxChangeDenominator": .config.optimism.eip1559Denominator|to_hex,
    "eip3238Transition": .config.londonBlock|to_hex,
    "eip3529Transition": .config.londonBlock|to_hex,
    "eip3541Transition": .config.londonBlock|to_hex,
    "eip3198Transition": .config.londonBlock|to_hex,

    # Merge
    "MergeForkIdTransition": .config.mergeForkBlock|to_hex,

    # Shanghai
    "eip3651TransitionTimestamp": .config.shanghaiTime|to_hex,
    "eip3855TransitionTimestamp": .config.shanghaiTime|to_hex,
    "eip3860TransitionTimestamp": .config.shanghaiTime|to_hex,
    "eip4895TransitionTimestamp": .config.shanghaiTime|to_hex,

    # Cancun
    "eip4844TransitionTimestamp": .config.cancunTime|to_hex,
    "eip4788TransitionTimestamp": .config.cancunTime|to_hex,
    "eip1153TransitionTimestamp": .config.cancunTime|to_hex,
    "eip5656TransitionTimestamp": .config.cancunTime|to_hex,
    "eip6780TransitionTimestamp": .config.cancunTime|to_hex,

    # OP forks
    "rip7212TransitionTimestamp": .config.fjordTime|to_hex,

    # Prague
    "eip2537TransitionTimestamp": .config.pragueTime|to_hex,
    "eip2935TransitionTimestamp": .config.pragueTime|to_hex,
    "eip6110TransitionTimestamp": .config.pragueTime|to_hex,
    "eip7002TransitionTimestamp": .config.pragueTime|to_hex,
    "eip7251TransitionTimestamp": .config.pragueTime|to_hex,
    "eip7702TransitionTimestamp": .config.pragueTime|to_hex,
    "eip7623TransitionTimestamp": .config.pragueTime|to_hex,
    "depositContractAddress": .config.depositContractAddress,

    "blobSchedule" : (if .config.blobSchedule then ((
      (.config as $c | ["cancun", "prague", "osaka", "amsterdam", "bpo1", "bpo2", "bpo3", "bpo4", "bpo5"]
      | map({ timestamp: $c[. + "Time"] } + $c.blobSchedule[.]))
    )
    | reverse
    | unique_by(.timestamp)
    | map(select(length > 1))
    ) else null end),

    # Osaka
    "eip7594TransitionTimestamp": .config.osakaTime|to_hex,
    "eip7823TransitionTimestamp": .config.osakaTime|to_hex,
    "eip7825TransitionTimestamp": .config.osakaTime|to_hex,
    "eip7883TransitionTimestamp": .config.osakaTime|to_hex,
    "eip7918TransitionTimestamp": .config.osakaTime|to_hex,

    # Fee collector
    "feeCollector":  (if .config.optimism != null then "0x4200000000000000000000000000000000000019" elif .config.taiko != null then "0x\(.config.chainId)0000000000000000000000000000010001" else null end),
    "eip1559FeeCollectorTransition": (if .config.optimism != null or .config.taiko != null then .config.londonBlock|to_hex else null end),

    # Other chain parameters
    "networkID": .config.chainId|to_hex,
    "chainID": .config.chainId|to_hex,

    "terminalTotalDifficulty": (if .config.taiko != null then "0x0" else .config.terminalTotalDifficulty|to_hex end),

    "eip1559BaseFeeMinValueTransition": .config.ontakeBlock|to_hex,
    "eip1559BaseFeeMinValue": (if .config.ontakeBlock then "0x86ff51" else null end),
  },
  "genesis": {
    "seal": {
      "ethereum":{
         "nonce": .nonce|infix_zeros_to_length(2;18),
         "mixHash": .mixHash,
      },
    },
    "difficulty": (if .config.taiko != null then "0x0" else .difficulty|to_hex end),
    "author": .coinbase,
    "timestamp": .timestamp,
    "parentHash": .parentHash,
    "extraData": .extraData,
    "gasLimit": .gasLimit,
    "baseFeePerGas": .baseFeePerGas,
    "blobGasUsed": .blobGasUsed,
    "excessBlobGas": .excessBlobGas,
    "parentBeaconBlockRoot": .parentBeaconBlockRoot,
  },
  "accounts": ((.alloc|with_entries(.key|=(if startswith("0x") then . else "0x" + . end)))),
}|remove_empty

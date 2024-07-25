package erc721

var (
	ABI = `[
		{
			"constant":true,
			"inputs":[
				{
					"name":"_tokenId",
					"type":"uint256"
				}
			],
			"name":"tokenURI",
			"outputs":[
				{
					"name":"",
					"type":"string"
				}
			],
			"payable":false,
			"stateMutability":"view",
			"type":"function"
		},
		{
			"constant": true,
			"inputs": [],
			"name": "symbol",
			"outputs": [
				{
					"name": "",
					"type": "string"
				}
			],
			"payable": false,
			"stateMutability": "view",
			"type": "function"
		}
	]`
)

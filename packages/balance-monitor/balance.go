package main

import (
	"fmt"
	"io/ioutil"
	"net/http"
	"strings"
)

func main() {

	url := "https://l1rpc.internal.taiko.xyz"
	method := "POST"

	payload := strings.NewReader(`{
		"id": 0,
		"jsonrpc": "2.0",
		"method": "eth_getBalance",
		"params": [
			"0xBcd4042DE499D14e55001CcbB24a551F3b954096",
			"latest"
		]
	}`)

	client := &http.Client{}
	req, err := http.NewRequest(method, url, payload)

	if err != nil {
		fmt.Println(err)
		return
	}
	req.Header.Add("Content-Type", "application/json")

	res, err := client.Do(req)
	if err != nil {
		fmt.Println(err)
		return
	}
	defer res.Body.Close()

	body, err := ioutil.ReadAll(res.Body)
	if err != nil {
		fmt.Println(err)
		return
	}
	fmt.Println(string(body))
}

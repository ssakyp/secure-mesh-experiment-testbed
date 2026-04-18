package main

import (
	"fmt"
	"io"
	"net/http"
)

func callService(url string) string {
	resp, err := http.Get(url)
	if err != nil {
		return fmt.Sprintf("Error calling %s: %s", url, err.Error())
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	return string(body)
}

func handler(w http.ResponseWriter, r *http.Request) {
	accountResp := callService("http://account-service:8080/")
	fraudResp := callService("http://fraud-analytics:8080/")

	fmt.Fprintf(w, "Transaction Orchestrator:\nAccount Service: %s\nFraud Analytics: %s\n", accountResp, fraudResp)
}

func main() {
	http.HandleFunc("/", handler)
	http.ListenAndServe(":8080", nil)
}

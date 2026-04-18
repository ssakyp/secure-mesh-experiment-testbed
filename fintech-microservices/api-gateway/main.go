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
	// Root route calls both auth and transaction
	authResp := callService("http://auth-service:8080/")
	txResp := callService("http://transaction-service:8080/")

	fmt.Fprintf(w, "API Gateway:\nAuth says: %s\nTransaction says: %s\n", authResp, txResp)
}

func main() {
	http.HandleFunc("/", handler)
	http.ListenAndServe(":8080", nil)
}

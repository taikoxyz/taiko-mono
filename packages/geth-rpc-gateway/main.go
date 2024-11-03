package main

import (
	"bytes"
	"encoding/json"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"net/url"
	"os"
	"strings"

	"github.com/gorilla/websocket"
)

type JSONRPCRequest struct {
	Method string `json:"method"`
}

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

var methodsUsingPrimary map[string]bool

func main() {
	// Load the target URLs from environment variables
	primaryURLStr := os.Getenv("TARGET_URL_PRIMARY")
	secondaryURLStr := os.Getenv("TARGET_URL_SECONDARY")
	webSocketURLStr := os.Getenv("WEBSOCKET_TARGET_URL")
	webSocketSecondaryURLStr := os.Getenv("WEBSOCKET_TARGET_URL_SECONDARY")

	if primaryURLStr == "" || secondaryURLStr == "" || webSocketURLStr == "" || webSocketSecondaryURLStr == "" {
		log.Fatal("TARGET_URL_PRIMARY, TARGET_URL_SECONDARY, WEBSOCKET_TARGET_URL, and WEBSOCKET_TARGET_URL_SECONDARY environment variables must be set")
	}

	primaryURL, err := url.Parse(primaryURLStr)
	if err != nil {
		log.Fatalf("Failed to parse primary target URL: %v", err)
	}
	secondaryURL, err := url.Parse(secondaryURLStr)
	if err != nil {
		log.Fatalf("Failed to parse secondary target URL: %v", err)
	}
	webSocketURL, err := url.Parse(webSocketURLStr)
	if err != nil {
		log.Fatalf("Failed to parse WebSocket target URL: %v", err)
	}
	webSocketSecondaryURL, err := url.Parse(webSocketSecondaryURLStr)
	if err != nil {
		log.Fatalf("Failed to parse WebSocket secondary target URL: %v", err)
	}

	methodsUsingPrimary = parsePrimaryMethods(os.Getenv("PRIMARY_METHODS"))
	enableDebugEndpoints := os.Getenv("ENABLE_DEBUG_ENDPOINTS") == "true"

	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		log.Printf("/healthz Received request: Method=%s, Path=%s", r.Method, r.URL.Path)
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if strings.ToLower(r.Header.Get("Upgrade")) == "websocket" {
			// Determine the WebSocket target URL based on the method
			var wsTargetURL *url.URL
			method := r.URL.Query().Get("method")
			if shouldUsePrimaryURL(method) {
				wsTargetURL = webSocketURL
				log.Printf("WebSocket request hitting WEBSOCKET_TARGET_URL with method: %s", method)
			} else {
				wsTargetURL = webSocketSecondaryURL
				log.Printf("WebSocket request hitting WEBSOCKET_TARGET_URL_SECONDARY with method: %s", method)
			}
			handleWebSocket(w, r, wsTargetURL)
			return
		}

		bodyBytes, err := ioutil.ReadAll(r.Body)
		if err != nil {
			http.Error(w, "Failed to read request body", http.StatusBadRequest)
			return
		}
		defer r.Body.Close()

		if len(bodyBytes) == 0 {
			w.Write([]byte("OK"))
			return
		}

		var jsonReq JSONRPCRequest
		if err := json.Unmarshal(bodyBytes, &jsonReq); err != nil {
			http.Error(w, "Invalid JSON in request body", http.StatusBadRequest)
			return
		}

		// Determine the HTTP target URL based on the method
		var targetURL *url.URL
		if shouldUsePrimaryURL(jsonReq.Method) {
			targetURL = primaryURL
			log.Printf("HTTP request hitting TARGET_URL_PRIMARY with method: %s", jsonReq.Method)
		} else {
			targetURL = secondaryURL
			log.Printf("HTTP request hitting TARGET_URL_SECONDARY with method: %s", jsonReq.Method)
		}

		if enableDebugEndpoints && isDebugMethod(jsonReq.Method) && jsonReq.Method != "debug_traceBlock" && jsonReq.Method != "debug_traceBlockByNumber" {
			http.Error(w, "Unsupported method", http.StatusBadRequest)
			return
		}

		proxyReq, err := http.NewRequest(r.Method, targetURL.String()+r.RequestURI, ioutil.NopCloser(bytes.NewReader(bodyBytes)))
		if err != nil {
			http.Error(w, "Failed to create request", http.StatusInternalServerError)
			return
		}

		for name, values := range r.Header {
			for _, value := range values {
				proxyReq.Header.Add(name, value)
			}
		}

		resp, err := http.DefaultClient.Do(proxyReq)
		if err != nil {
			http.Error(w, "Failed to reach target server", http.StatusInternalServerError)
			return
		}
		defer resp.Body.Close()

		for name, values := range resp.Header {
			for _, value := range values {
				w.Header().Add(name, value)
			}
		}

		w.WriteHeader(resp.StatusCode)
		io.Copy(w, resp.Body)
	})

	log.Fatal(http.ListenAndServe(":8080", nil))
}

func isDebugMethod(method string) bool {
	return len(method) >= 6 && method[:6] == "debug_" && method != "debug_traceBlock"
}

// Parses the PRIMARY_METHODS environment variable and returns a map of methods using the primary URL
func parsePrimaryMethods(methods string) map[string]bool {
	methodMap := make(map[string]bool)
	for _, method := range strings.Split(methods, ",") {
		method = strings.TrimSpace(method)
		if method != "" {
			methodMap[method] = true
		}
	}
	return methodMap
}

// Checks if a method should use the primary URL
func shouldUsePrimaryURL(method string) bool {
	return methodsUsingPrimary[method]
}

func handleWebSocket(w http.ResponseWriter, r *http.Request, targetURL *url.URL) {
	clientConn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("Failed to upgrade connection: %v", err)
		http.Error(w, "Failed to upgrade to WebSocket", http.StatusInternalServerError)
		return
	}
	defer clientConn.Close()

	targetConn, _, err := websocket.DefaultDialer.Dial(targetURL.String(), nil)
	if err != nil {
		log.Printf("Failed to connect to target WebSocket server: %v", err)
		http.Error(w, "Failed to connect to target WebSocket server", http.StatusInternalServerError)
		return
	}
	defer targetConn.Close()

	go func() {
		for {
			messageType, message, err := clientConn.ReadMessage()
			if err != nil {
				log.Printf("Error reading message from client: %v", err)
				return
			}
			if err := targetConn.WriteMessage(messageType, message); err != nil {
				log.Printf("Error writing message to target server: %v", err)
				return
			}
		}
	}()

	for {
		messageType, message, err := targetConn.ReadMessage()
		if err != nil {
			log.Printf("Error reading message from target server: %v", err)
			return
		}
		if err := clientConn.WriteMessage(messageType, message); err != nil {
			log.Printf("Error writing message to client: %v", err)
			return
		}
	}
}

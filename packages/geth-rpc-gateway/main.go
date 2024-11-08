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

var (
	upgrader             = websocket.Upgrader{CheckOrigin: func(r *http.Request) bool { return true }}
	methodsUsingPrimary  map[string]bool
	primaryURL           *url.URL
	secondaryURL         *url.URL
	webSocketURL         *url.URL
	enableDebugEndpoints bool
)

func main() {
	// Load the target URLs from environment variables
	var err error
	primaryURL, err = url.Parse(os.Getenv("TARGET_URL_PRIMARY"))
	if err != nil || primaryURL == nil {
		log.Fatalf("Failed to parse primary target URL: %v", err)
	}
	secondaryURL, err = url.Parse(os.Getenv("TARGET_URL_SECONDARY"))
	if err != nil || secondaryURL == nil {
		log.Fatalf("Failed to parse secondary target URL: %v", err)
	}
	webSocketURL, err = url.Parse(os.Getenv("WEBSOCKET_TARGET_URL"))
	if err != nil || webSocketURL == nil {
		log.Fatalf("Failed to parse WebSocket target URL: %v", err)
	}

	methodsUsingPrimary = parsePrimaryMethods(os.Getenv("PRIMARY_METHODS"))
	enableDebugEndpoints = os.Getenv("ENABLE_DEBUG_ENDPOINTS") == "true"

	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		log.Printf("/healthz Received request: Method=%s, Path=%s", r.Method, r.URL.Path)
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	// Determine if server should handle WebSocket or RPC based on environment variable
	if os.Getenv("IS_WEBSOCKET") == "true" {
		log.Println("Starting in WebSocket mode")
		http.HandleFunc("/", rootWebSocketHandler) // WebSocket handler without CORS
	} else {
		log.Println("Starting in RPC mode")
		http.Handle("/", enableCORS(http.HandlerFunc(rootHandler))) // HTTP handler with CORS middleware
	}

	log.Fatal(http.ListenAndServe(":8080", nil))
}

// WebSocket handler for `/` path when in WebSocket mode
func rootWebSocketHandler(w http.ResponseWriter, r *http.Request) {
	log.Printf("WebSocket connection initiated...")
	handleWebSocket(w, r, webSocketURL)
}

// CORS middleware to enable CORS headers
func enableCORS(next http.Handler) http.Handler {
	log.Printf("enableCORS")
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Printf("CORS middleware invoked for %s %s", r.Method, r.URL.Path)

		// Get the Origin header from the request
		origin := r.Header.Get("Origin")

		// Set Access-Control-Allow-Origin only if the request has an Origin header
		if origin != "" {
			log.Printf("CORS middleware invoked for origin %s", origin)
			w.Header().Del("Access-Control-Allow-Origin") // Clear any existing header
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Vary", "Origin") // Ensure caching based on origin
		}

		w.Header().Set("Access-Control-Allow-Methods", r.Method)
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		w.WriteHeader(http.StatusOK)

		next.ServeHTTP(w, r)
	})
}

func rootHandler(w http.ResponseWriter, r *http.Request) {
	log.Printf("rootHandler...")

	// Check for WebSocket Upgrade
	if strings.ToLower(r.Header.Get("Upgrade")) == "websocket" {
		handleWebSocket(w, r, webSocketURL)
		return
	}

	// Handle HTTP requests

	bodyBytes, err := ioutil.ReadAll(r.Body)

	log.Printf("Handle HTTP requests...")
	if err != nil {
		log.Printf("Error")

		http.Error(w, "Failed to read request body", http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	if len(bodyBytes) == 0 {
		w.Write([]byte("OK"))
		return
	}

	// Determine the target URL and extract methods
	usePrimaryURL, methods := shouldUsePrimaryURL(bodyBytes)
	var targetURL *url.URL
	if usePrimaryURL {
		targetURL = primaryURL
		log.Printf("HTTP request hitting TARGET_URL_PRIMARY")
	} else {
		targetURL = secondaryURL
		log.Printf("HTTP request hitting TARGET_URL_SECONDARY")
	}

	// Check each method for debug restrictions
	for _, method := range methods {
		if enableDebugEndpoints && isDebugMethod(method) && method != "debug_traceBlock" && method != "debug_traceBlockByNumber" {
			http.Error(w, "Unsupported method", http.StatusBadRequest)
			return
		}
	}

	// Forward the original JSON payload as-is to the target URL
	forwardRequest(w, r, targetURL, bodyBytes)
}

// Function to forward the request to the target URL
func forwardRequest(w http.ResponseWriter, r *http.Request, targetURL *url.URL, bodyBytes []byte) {

	proxyReq, err := http.NewRequest(r.Method, targetURL.String()+r.RequestURI, ioutil.NopCloser(bytes.NewReader(bodyBytes)))
	if err != nil {
		http.Error(w, "Failed to create request", http.StatusInternalServerError)
		return
	}

	// Copy headers from the original request, excluding Accept-Encoding
	for name, values := range r.Header {
		log.Printf("proxy req name %s, value %s", name, values)
		if name == "Accept-Encoding" {
			continue
		}
		for _, value := range values {
			proxyReq.Header.Add(name, value)
		}
	}

	// Send the request to the target URL
	resp, err := http.DefaultClient.Do(proxyReq)
	if err != nil {
		http.Error(w, "Failed to reach target server", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	// Log headers before setting them to diagnose any discrepancies
	log.Printf("Received Content-Type from upstream: %s", resp.Header.Get("Content-Type"))

	// Prepare to copy headers from the response
	for name, values := range resp.Header {
		log.Printf("response name %s, value %s", name, values)
		switch name {
		case "Content-Length", "Transfer-Encoding", "Connection":
			// Skip these headers
			continue
		default:
			for _, value := range values {
				w.Header().Add(name, value)
			}
		}
	}

	// Explicitly set Content-Type if it's present in the response
	if contentType := resp.Header.Get("Content-Type"); contentType != "" {
		w.Header().Set("Content-Type", contentType)
	} else {
		w.Header().Set("Content-Type", "application/json") // default if not provided
	}
	log.Printf("Set Content-Type header: %s", w.Header().Get("Content-Type"))

	// Read the response body into a buffer to set Content-Type explicitly
	var buf bytes.Buffer
	if _, err := io.Copy(&buf, resp.Body); err != nil {
		log.Printf("Error reading response body into buffer: %v", err)
		http.Error(w, "Failed to read response body", http.StatusInternalServerError)
		return
	}

	// Write status code and ensure Content-Type is set
	w.WriteHeader(resp.StatusCode)
	log.Printf("Response status code: %d", resp.StatusCode)
	log.Printf("Final Content-Type header: %s", w.Header().Get("Content-Type"))

	// Write the buffered body to the response
	if _, err := io.Copy(w, &buf); err != nil {
		log.Printf("Error copying buffer to response: %v", err)
	}
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

// Checks if any method should use the primary URL and returns all methods
func shouldUsePrimaryURL(bodyBytes []byte) (bool, []string) {
	var singleRequest JSONRPCRequest
	var multipleRequests []JSONRPCRequest
	methods := []string{}

	// Try unmarshalling as a single request
	if err := json.Unmarshal(bodyBytes, &singleRequest); err == nil {
		methods = append(methods, singleRequest.Method)
		return methodsUsingPrimary[singleRequest.Method], methods
	}

	// Try unmarshalling as an array of requests
	if err := json.Unmarshal(bodyBytes, &multipleRequests); err == nil {
		usePrimary := false
		for _, req := range multipleRequests {
			methods = append(methods, req.Method)
			if methodsUsingPrimary[req.Method] {
				usePrimary = true
			}
		}
		return usePrimary, methods
	}

	log.Printf("Invalid JSON in request body: unable to parse as single or multiple requests")
	return false, methods // Default to secondary URL if JSON is invalid
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

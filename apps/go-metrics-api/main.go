package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"runtime"
	"syscall"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

const (
	version     = "1.0.0"
	defaultPort = "8080"
)

// Prometheus metrics — all scoped under the "api" namespace for dashboard grouping.
var (
	requestsTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Namespace: "api",
		Name:      "http_requests_total",
		Help:      "Total HTTP requests partitioned by method, path, and status code.",
	}, []string{"method", "path", "status"})

	requestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Namespace: "api",
		Name:      "http_request_duration_seconds",
		Help:      "HTTP request latency in seconds.",
		Buckets:   prometheus.DefBuckets,
	}, []string{"method", "path"})

	buildInfo = promauto.NewGaugeVec(prometheus.GaugeOpts{
		Namespace: "api",
		Name:      "build_info",
		Help:      "Build metadata. Always 1.",
	}, []string{"version", "go_version"})
)

// statusWriter wraps ResponseWriter to capture the written HTTP status code.
type statusWriter struct {
	http.ResponseWriter
	status int
}

func (sw *statusWriter) WriteHeader(code int) {
	sw.status = code
	sw.ResponseWriter.WriteHeader(code)
}

// instrument wraps an HTTP handler to record request count and duration metrics.
func instrument(path string, h http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rw := &statusWriter{ResponseWriter: w, status: http.StatusOK}
		h(rw, r)
		requestsTotal.WithLabelValues(r.Method, path, fmt.Sprintf("%d", rw.status)).Inc()
		requestDuration.WithLabelValues(r.Method, path).Observe(time.Since(start).Seconds())
	}
}

// writeJSON sends a JSON response with the given status code.
func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

// handleRoot returns service metadata. Reads POD_NAME and NODE_NAME from the
// Kubernetes downward API (injected via the Deployment spec).
func handleRoot(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{
		"service":  "go-metrics-api",
		"version":  version,
		"status":   "ok",
		"pod":      os.Getenv("POD_NAME"),
		"node":     os.Getenv("NODE_NAME"),
		"message":  "Production-grade Go service running on GKE with Istio + Prometheus",
	})
}

// handleHealthz is the liveness probe endpoint.
// Returns 200 as long as the process is running.
func handleHealthz(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "healthy"})
}

// handleReadyz is the readiness probe endpoint.
// Returns 200 when the service is ready to handle traffic.
// Add real dependency checks (DB ping, cache check) here as needed.
func handleReadyz(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
}

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))
	slog.SetDefault(logger)

	port := os.Getenv("PORT")
	if port == "" {
		port = defaultPort
	}

	// Emit build info metric on startup (visible in Grafana for version tracking).
	buildInfo.WithLabelValues(version, runtime.Version()).Set(1)

	mux := http.NewServeMux()
	mux.HandleFunc("/", instrument("/", handleRoot))
	mux.HandleFunc("/healthz", handleHealthz)
	mux.HandleFunc("/readyz", handleReadyz)
	mux.Handle("/metrics", promhttp.Handler()) // Prometheus scrape endpoint.

	srv := &http.Server{
		Addr:         ":" + port,
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	// Start in a goroutine so the main goroutine can listen for shutdown signals.
	go func() {
		slog.Info("server started", "port", port, "version", version)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("server error", "error", err)
			os.Exit(1)
		}
	}()

	// Block until SIGTERM (from Kubernetes) or SIGINT (Ctrl+C).
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	slog.Info("shutdown signal received, draining connections...")

	// Give in-flight requests 30 seconds to complete before forceful exit.
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		slog.Error("graceful shutdown failed", "error", err)
		os.Exit(1)
	}

	slog.Info("server stopped cleanly")
}

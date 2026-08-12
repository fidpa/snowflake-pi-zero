#!/usr/bin/env python3
"""
Snowflake Metrics HTTP Server
Simple HTTP server to expose Snowflake metrics for Prometheus scraping

Version: 1.1.0
Created: 12. Januar 2026
Port: 9092

Usage:
    ./snowflake-metrics-server.py <device-name>

Examples:
    ./snowflake-metrics-server.py bedroom
    ./snowflake-metrics-server.py bathroom
    ./snowflake-metrics-server.py pi-zero-01
    ./snowflake-metrics-server.py snowflake
"""

import sys
import signal
import logging
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler

# Configuration
PORT = 9092
METRICS_DIR = Path("/var/lib/node_exporter/textfile_collector")

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class MetricsHandler(BaseHTTPRequestHandler):
    """HTTP handler for Prometheus metrics endpoint"""

    location = "unknown"

    def do_GET(self) -> None:
        """Handle GET requests to /metrics"""
        if self.path == "/metrics" or self.path == "/":
            self.send_metrics()
        elif self.path == "/health":
            self.send_health()
        else:
            self.send_error(404, "Not Found")

    def send_metrics(self) -> None:
        """Send Snowflake metrics"""
        metrics_file = METRICS_DIR / f"snowflake_{self.location}.prom"

        if metrics_file.exists():
            content = metrics_file.read_text()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.end_headers()
            self.wfile.write(content.encode())
        else:
            # Return empty metrics with comment
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.end_headers()
            self.wfile.write(f"# No metrics available for {self.location}\n".encode())

    def send_health(self) -> None:
        """Send health check response"""
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"OK\n")

    def log_message(self, format: str, *args) -> None:
        """Suppress default logging (too verbose)"""
        pass


def signal_handler(signum: int, frame) -> None:
    """Handle shutdown signals"""
    logger.info(f"Received signal {signum}, shutting down...")
    sys.exit(0)


def main() -> int:
    """Main entry point"""
    if len(sys.argv) < 2:
        print("Usage: snowflake-metrics-server.py <device-name>")
        print("Example: snowflake-metrics-server.py bedroom")
        return 1

    location = sys.argv[1]

    # Set location for handler
    MetricsHandler.location = location

    # Register signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    # Start HTTP server
    server = HTTPServer(("0.0.0.0", PORT), MetricsHandler)
    logger.info(f"Snowflake metrics server started on port {PORT} for {location}")
    logger.info(f"Metrics endpoint: http://0.0.0.0:{PORT}/metrics")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        logger.info("Server stopped")

    return 0


if __name__ == "__main__":
    sys.exit(main())

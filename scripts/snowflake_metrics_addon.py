#!/usr/bin/env python3
"""
Snowflake Metrics Addon for Prometheus Exporter
Reads textfile collector metrics and registers them with prometheus_client

Version: 1.0.0
Created: 12. Januar 2026
Devices: GPIO Pi Zeros (Bedroom, Bathroom)

Usage:
    from snowflake_metrics_addon import SnowflakeMetrics
    snowflake = SnowflakeMetrics(location="bedroom")
    snowflake.update()  # Call in main loop
"""

import re
import logging
from pathlib import Path
from prometheus_client import Gauge

logger = logging.getLogger(__name__)


class SnowflakeMetrics:
    """
    Read Snowflake metrics from textfile and export via prometheus_client

    Metrics:
    - snowflake_connected_clients{device}
    - snowflake_bytes_proxied_total{device}
    - snowflake_proxy_uptime_seconds{device}
    - snowflake_service_status{device}
    """

    def __init__(self, location: str = "bedroom"):
        """
        Initialize Snowflake metrics collector

        Args:
            location: Device location (bedroom or bathroom)
        """
        self.location = location
        self.metrics_file = Path(f"/var/lib/node_exporter/textfile_collector/snowflake_{location}.prom")

        # Register Prometheus gauges
        self.connected_clients = Gauge(
            'snowflake_connected_clients',
            'Number of Tor clients connected in last summary interval',
            ['device']
        )
        self.bytes_proxied = Gauge(
            'snowflake_bytes_proxied_total',
            'Total bytes proxied through Snowflake in last interval',
            ['device']
        )
        self.uptime = Gauge(
            'snowflake_proxy_uptime_seconds',
            'Snowflake proxy uptime in seconds',
            ['device']
        )
        self.service_status = Gauge(
            'snowflake_service_status',
            'Snowflake service status (1=running, 0=stopped)',
            ['device']
        )

        logger.info(f"SnowflakeMetrics initialized for {location}")

    def update(self) -> bool:
        """
        Read metrics from textfile and update Prometheus gauges

        Returns:
            True if metrics were successfully read, False otherwise
        """
        if not self.metrics_file.exists():
            logger.debug(f"Metrics file not found: {self.metrics_file}")
            return False

        try:
            content = self.metrics_file.read_text()

            # Parse metrics using regex
            patterns = {
                'connected_clients': r'snowflake_connected_clients\{device="[^"]+"\}\s+(\d+)',
                'bytes_proxied': r'snowflake_bytes_proxied_total\{device="[^"]+"\}\s+(\d+)',
                'uptime': r'snowflake_proxy_uptime_seconds\{device="[^"]+"\}\s+(\d+)',
                'status': r'snowflake_service_status\{device="[^"]+"\}\s+(\d+)'
            }

            for key, pattern in patterns.items():
                match = re.search(pattern, content)
                if match:
                    value = float(match.group(1))
                    if key == 'connected_clients':
                        self.connected_clients.labels(device=self.location).set(value)
                    elif key == 'bytes_proxied':
                        self.bytes_proxied.labels(device=self.location).set(value)
                    elif key == 'uptime':
                        self.uptime.labels(device=self.location).set(value)
                    elif key == 'status':
                        self.service_status.labels(device=self.location).set(value)

            return True

        except Exception as e:
            logger.error(f"Failed to read Snowflake metrics: {e}")
            return False


def get_snowflake_status(location: str = "bedroom") -> dict:
    """
    Get current Snowflake status as dict (for non-Prometheus use)

    Args:
        location: Device location

    Returns:
        Dict with current metrics or empty dict on error
    """
    metrics_file = Path(f"/var/lib/node_exporter/textfile_collector/snowflake_{location}.prom")

    if not metrics_file.exists():
        return {}

    try:
        content = metrics_file.read_text()
        result = {}

        patterns = {
            'connected_clients': r'snowflake_connected_clients\{device="[^"]+"\}\s+(\d+)',
            'bytes_proxied': r'snowflake_bytes_proxied_total\{device="[^"]+"\}\s+(\d+)',
            'uptime_seconds': r'snowflake_proxy_uptime_seconds\{device="[^"]+"\}\s+(\d+)',
            'service_status': r'snowflake_service_status\{device="[^"]+"\}\s+(\d+)'
        }

        for key, pattern in patterns.items():
            match = re.search(pattern, content)
            if match:
                result[key] = int(match.group(1))

        return result

    except Exception:
        return {}

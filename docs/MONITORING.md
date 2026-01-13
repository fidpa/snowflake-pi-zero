# Monitoring Guide

## Metrics Overview

Snowflake Proxy exports four key metrics via Prometheus:

| Metric | Type | Description |
|--------|------|-------------|
| `snowflake_connected_clients` | Gauge | Number of Tor clients connected in last summary interval |
| `snowflake_bytes_proxied_total` | Counter | Total bytes proxied through Snowflake |
| `snowflake_proxy_uptime_seconds` | Gauge | Proxy process uptime in seconds |
| `snowflake_service_status` | Gauge | Service status (1=running, 0=stopped) |

All metrics include a `device` label for multi-device setups.

## Prometheus Setup

### 1. Install Prometheus

```bash
sudo apt update
sudo apt install -y prometheus
```

### 2. Configure Scrape Target

Add to `/etc/prometheus/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'snowflake-proxy'
    static_configs:
      - targets:
          - 'localhost:9092'  # Local device
          # Add more devices:
          # - '192.168.1.100:9092'
          # - '192.168.1.101:9092'
        labels:
          service: 'snowflake'
          type: 'tor-proxy'
    scrape_interval: 30s
    scrape_timeout: 10s
```

### 3. Restart Prometheus

```bash
sudo systemctl restart prometheus
```

### 4. Verify Scraping

Visit `http://localhost:9090/targets` and confirm `snowflake-proxy` target is UP.

## Grafana Dashboard

### Import Dashboard

1. Open Grafana (typically `http://localhost:3000`)
2. Navigate to **Dashboards** → **Import**
3. Upload `monitoring/grafana-dashboard.json`
4. Select your Prometheus datasource
5. Click **Import**

### Dashboard Panels

The dashboard includes:

- **Service Status**: Real-time service health (Running/Stopped)
- **Connected Tor Clients**: Time-series graph of active connections
- **Bytes Proxied Rate**: Network traffic throughput
- **Device Details**: Per-device statistics (clients, bytes, uptime)

### Customizing Queries

Example queries for custom panels:

```promql
# Total connections across all devices
sum(snowflake_connected_clients)

# Average uptime across fleet
avg(snowflake_proxy_uptime_seconds) / 3600

# Traffic rate (5-minute average)
rate(snowflake_bytes_proxied_total[5m])

# Connection success rate (if you add custom metrics)
sum(rate(snowflake_connection_success_total[5m])) / sum(rate(snowflake_connection_attempts_total[5m]))
```

## Alerting

### Prometheus Alerts

Add to `/etc/prometheus/alert.rules.yml`:

```yaml
groups:
  - name: snowflake_alerts
    interval: 30s
    rules:
      - alert: SnowflakeServiceDown
        expr: snowflake_service_status == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Snowflake proxy down on {{ $labels.device }}"

      - alert: SnowflakeHighMemory
        expr: snowflake_proxy_memory_bytes > 120000000
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.device }}"
```

Reference `/etc/prometheus/alert.rules.yml` in `prometheus.yml`:

```yaml
rule_files:
  - /etc/prometheus/alert.rules.yml
```

### Telegram Alerts (Optional)

For Telegram integration, use [Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/):

```bash
sudo apt install -y prometheus-alertmanager
```

Configure `alertmanager.yml`:

```yaml
global:
  resolve_timeout: 5m

route:
  receiver: 'telegram'
  group_wait: 10s
  group_interval: 5m
  repeat_interval: 3h

receivers:
  - name: 'telegram'
    telegram_configs:
      - bot_token: 'YOUR_BOT_TOKEN'
        chat_id: YOUR_CHAT_ID
        message: '{{ template "telegram.default" . }}'
```

## Performance Baselines

Normal operating metrics for Pi Zero 2W:

| Metric | Expected Range |
|--------|---------------|
| Memory Usage | 15-40 MB |
| CPU Usage | 2-10% |
| Uptime | Days to weeks |
| Connections | 0-5 per device |
| Traffic | Highly variable (1 KB - 1 GB per connection) |

## Daily Health Checks

Quick 5-minute verification routine:

```bash
# 1. Service status
systemctl status snowflake-proxy.service

# 2. Recent connections
tail -n 20 /var/log/snowflake/snowflake-proxy.log | grep "connections"

# 3. Memory usage
ps aux | grep snowflake-proxy | awk '{print $6/1024 " MB"}'

# 4. Bandwidth limit
/opt/snowflake/verify-bandwidth.sh

# 5. Metrics endpoint
curl -s http://localhost:9092/metrics | grep snowflake_service_status
```

## Advanced Monitoring

### Add Custom Metrics

Edit `snowflake-metrics-exporter.sh` to export additional metrics:

```bash
# Example: WiFi signal strength
WIFI_SIGNAL=$(iw dev wlan0 link | grep signal | awk '{print $2}')
echo "snowflake_wifi_signal_dbm{device=\"$DEVICE_NAME\"} $WIFI_SIGNAL" >> "$METRICS_FILE"
```

### Log Aggregation

For centralized logging, use Promtail + Loki:

```bash
# Install Promtail
sudo apt install -y promtail

# Configure to scrape /var/log/snowflake/*.log
```

### Long-term Metrics Storage

Configure Prometheus retention:

```yaml
# In prometheus.yml
storage:
  tsdb:
    retention.time: 90d  # Keep 90 days of data
```

## Troubleshooting Monitoring

### Metrics Not Appearing

1. Check metrics file exists:
   ```bash
   ls -lh /var/lib/node_exporter/textfile_collector/snowflake_*.prom
   ```

2. Check metrics content:
   ```bash
   cat /var/lib/node_exporter/textfile_collector/snowflake_*.prom
   ```

3. Verify timer is running:
   ```bash
   systemctl status snowflake-metrics-exporter.timer
   ```

### Prometheus Can't Scrape

1. Check metrics server is running:
   ```bash
   systemctl status snowflake-metrics-server.service
   ```

2. Test endpoint locally:
   ```bash
   curl http://localhost:9092/metrics
   ```

3. Check firewall rules:
   ```bash
   sudo ufw status
   ```

### High CPU Usage

Reduce scrape frequency in `prometheus.yml`:

```yaml
scrape_interval: 60s  # Increase from 30s to 60s
```

Or reduce metrics server update frequency:

```bash
sudo systemctl edit snowflake-metrics-exporter.timer

# Change OnUnitActiveSec to 10min instead of 5min
```

## Next Steps

- [Review troubleshooting guide](TROUBLESHOOTING.md)
- [Understand performance factors](PERFORMANCE.md)
- [Join Tor community forums](https://forum.torproject.net/)

# Troubleshooting Guide

## TL;DR

Service won't start? Check `journalctl -u snowflake-proxy.service -n 50`. No connections after 24h? Normal - wait 2-3 days. High memory (>120MB)? Restart service or reduce capacity to 3. WiFi drops? Target -66 dBm or better. Complete reset: run `install.sh` again.

---

## Table of Contents

- [Service Issues](#service-issues)
- [Connection Issues](#connection-issues)
- [Resource Issues](#resource-issues)
- [Monitoring Issues](#monitoring-issues)
- [Bandwidth Limiting Issues](#bandwidth-limiting-issues)
- [Complete System Failure](#complete-system-failure)
- [Getting Help](#getting-help)

---

## Service Issues

### Service Won't Start

**Symptoms**: `systemctl status snowflake-proxy.service` shows "failed" or "inactive"

**Diagnosis**:
```bash
# Check logs
sudo journalctl -u snowflake-proxy.service -n 100

# Check binary exists and is executable
ls -lh /opt/snowflake/snowflake-proxy
file /opt/snowflake/snowflake-proxy

# Verify service user exists
id snowflake
```

**Solutions**:

1. **Binary not found**:
   ```bash
   sudo apt install tor-snowflake-proxy
   # Or copy binary manually to /opt/snowflake/
   ```

2. **Permission denied**:
   ```bash
   sudo chmod +x /opt/snowflake/snowflake-proxy
   sudo chown snowflake:snowflake /opt/snowflake/snowflake-proxy
   ```

3. **User doesn't exist**:
   ```bash
   sudo useradd --system --no-create-home snowflake
   ```

4. **Port already in use**:
   ```bash
   # Check what's using port 9092
   sudo lsof -i :9092
   # Kill conflicting process or change port in service file
   ```

### Service Crashes Repeatedly

**Symptoms**: Service starts but stops after a few seconds

**Diagnosis**:
```bash
# Check crash logs
sudo journalctl -u snowflake-proxy.service --since "10 minutes ago"

# Check system resources
free -h
df -h
```

**Solutions**:

1. **Out of memory**:
   - Reduce capacity: Edit `/etc/systemd/system/snowflake-proxy.service`
   - Change `-capacity 5` to `-capacity 3`
   - Reduce `MemoryMax` from 128M to 96M

2. **Disk full**:
   ```bash
   # Clean old logs
   sudo journalctl --vacuum-time=7d
   sudo truncate -s 0 /var/log/snowflake/*.log
   ```

3. **Corrupted binary**:
   ```bash
   # Reinstall
   sudo apt remove tor-snowflake-proxy
   sudo apt install tor-snowflake-proxy
   ```

## Connection Issues

### No Tor Connections After 24 Hours

**Symptoms**: `snowflake_connected_clients` always shows 0

**Diagnosis**:
```bash
# Check service is running
systemctl is-active snowflake-proxy.service

# Check logs for connection attempts
grep "WebRTC" /var/log/snowflake/snowflake-proxy.log

# Check NAT type
# (Install stun-client: sudo apt install stun-client)
stunclient stun.l.google.com:19302
```

**This is often NORMAL**: Tor broker distributes connections based on global demand. Low activity is expected for new proxies.

**Solutions**:

1. **Wait longer**: It can take 2-3 days to receive first connection
2. **Check firewall**: Ensure UDP ports are not blocked
3. **Verify internet connectivity**:
   ```bash
   ping -c 4 1.1.1.1
   curl -I https://snowflake-broker.torproject.net
   ```

4. **Check NAT type**: Restrictive NAT (`port-restricted` or `symmetric`) reduces effectiveness
   - Solution: Port forward UDP range in router (not always necessary)

### Connections Drop Frequently

**Symptoms**: Logs show "Timed out waiting for client to open data channel"

**Diagnosis**:
```bash
# Check WiFi signal strength
iw dev wlan0 link | grep signal

# Check network stability
ping -c 100 1.1.1.1 | tail -5

# Check bandwidth limit
/opt/snowflake/verify-bandwidth.sh
```

**Solutions**:

1. **Poor WiFi signal** (< -70 dBm):
   - Move device closer to router
   - Use external antenna
   - Switch to 5 GHz band if available
   - Use Ethernet adapter instead

2. **Bandwidth too restrictive**:
   ```bash
   # Increase daytime limit
   sudo /opt/snowflake/tc-bandwidth-limiter.sh nighttime  # 20 Mbps
   ```

3. **Network congestion**:
   - Reduce capacity to 3 clients
   - Schedule maintenance windows

## Resource Issues

### High Memory Usage (>120MB)

**Symptoms**: `snowflake_proxy_memory_bytes` > 120MB

**Diagnosis**:
```bash
# Check current usage
ps aux | grep snowflake-proxy | awk '{print $6/1024 " MB"}'

# Monitor over time
watch -n 5 'ps aux | grep snowflake-proxy | awk "{print \$6/1024 \" MB\"}"'
```

**Solutions**:

1. **Gradual increase (memory leak)**:
   ```bash
   # Restart service
   sudo systemctl restart snowflake-proxy.service
   ```

2. **Stable high usage (too many clients)**:
   - Reduce capacity from 5 to 3 clients
   - Lower `MemoryMax` limit to trigger earlier OOM kill

3. **Add automatic restart on high memory**:
   ```bash
   # Add to crontab
   */15 * * * * if [ $(ps -C snowflake-proxy -o rss= | awk '{sum+=$1} END {print sum/1024}') -gt 120 ]; then systemctl restart snowflake-proxy.service; fi
   ```

### High CPU Usage (>30%)

**Symptoms**: `top` shows snowflake-proxy using >30% CPU consistently

**Diagnosis**:
```bash
# Check CPU usage
top -b -n 1 | grep snowflake

# Check active connections
grep "connections" /var/log/snowflake/snowflake-proxy.log | tail -5
```

**Solutions**:

1. **Too many simultaneous connections**:
   - Reduce capacity to 3
   - Lower `CPUQuota` in service file to 20%

2. **Bandwidth saturation**:
   - Apply stricter bandwidth limit
   - Check if upstream ISP is throttling

3. **Sensor interference** (if running other monitoring on same device):
   - Increase sensor nice priority: `nice -n 10`

## Monitoring Issues

### Metrics Not Updating

**Symptoms**: Prometheus shows stale metrics or no data

**Diagnosis**:
```bash
# Check timer is active
systemctl status snowflake-metrics-exporter.timer

# Check last run
systemctl list-timers | grep snowflake

# Check metrics file
cat /var/lib/node_exporter/textfile_collector/snowflake_*.prom
```

**Solutions**:

1. **Timer not running**:
   ```bash
   sudo systemctl start snowflake-metrics-exporter.timer
   sudo systemctl enable snowflake-metrics-exporter.timer
   ```

2. **Metrics file empty or missing**:
   ```bash
   # Manually trigger export
   sudo -u pi /opt/snowflake/snowflake-metrics-exporter.sh snowflake
   ```

3. **Permissions issue**:
   ```bash
   sudo chown pi:pi /var/lib/node_exporter/textfile_collector/snowflake_*.prom
   ```

### Grafana Dashboard Shows No Data

**Diagnosis**:
```bash
# Check Prometheus is scraping
curl http://localhost:9090/api/v1/targets

# Test query directly
curl -G http://localhost:9090/api/v1/query --data-urlencode 'query=snowflake_service_status'
```

**Solutions**:

1. **Wrong datasource**:
   - Edit dashboard, select correct Prometheus datasource

2. **Time range too narrow**:
   - Expand time range to "Last 24 hours"

3. **Metric names changed**:
   - Verify metric names match: `curl http://localhost:9092/metrics`

## Bandwidth Limiting Issues

### Bandwidth Limit Not Applied

**Symptoms**: `verify-bandwidth.sh` shows "No TBF qdisc configured"

**Diagnosis**:
```bash
# Check current qdisc
sudo tc qdisc show dev wlan0

# Check cron jobs
sudo crontab -l | grep bandwidth
```

**Solutions**:

1. **Manual application**:
   ```bash
   sudo /opt/snowflake/tc-bandwidth-limiter.sh daytime
   ```

2. **Missing cron job**:
   ```bash
   sudo crontab -e
   # Add:
   0 9 * * * /opt/snowflake/tc-bandwidth-limiter.sh daytime
   0 0 * * * /opt/snowflake/tc-bandwidth-limiter.sh nighttime
   ```

3. **Wrong interface**:
   ```bash
   # Check active interface
   ip link show
   # Update script with correct interface
   ```

### Profile Mismatch

**Symptoms**: `verify-bandwidth.sh` shows "MISMATCH"

**Diagnosis**:
```bash
# Check current profile
sudo tc qdisc show dev wlan0 | grep rate

# Check current hour
date +%H
```

**Solutions**:

1. **Cron not running**:
   ```bash
   sudo systemctl status cron
   sudo systemctl start cron
   ```

2. **Manual fix**:
   ```bash
   HOUR=$(date +%H)
   if [ $HOUR -ge 9 ]; then
       sudo /opt/snowflake/tc-bandwidth-limiter.sh daytime
   else
       sudo /opt/snowflake/tc-bandwidth-limiter.sh nighttime
   fi
   ```

## Complete System Failure

### Rollback to Clean State

If everything is broken, reset to default:

```bash
# Stop all services
sudo systemctl stop snowflake-proxy.service
sudo systemctl stop snowflake-metrics-exporter.timer
sudo systemctl stop snowflake-metrics-server.service

# Disable services
sudo systemctl disable snowflake-proxy.service
sudo systemctl disable snowflake-metrics-exporter.timer
sudo systemctl disable snowflake-metrics-server.service

# Remove bandwidth limits
sudo /opt/snowflake/tc-bandwidth-limiter.sh remove

# Clean installation
sudo rm -rf /opt/snowflake
sudo rm -f /etc/systemd/system/snowflake-*
sudo systemctl daemon-reload

# Reinstall from scratch
curl -sSL https://raw.githubusercontent.com/fidpa/snowflake-pi-zero/main/install.sh | bash
```

## Getting Help

### Useful Commands for Bug Reports

```bash
# System info
uname -a
cat /etc/os-release
free -h
df -h

# Service status
systemctl status snowflake-proxy.service
journalctl -u snowflake-proxy.service -n 50

# Network status
ip link show
iw dev wlan0 link

# Last 20 log lines
tail -20 /var/log/snowflake/snowflake-proxy.log
```

### Community Resources

- [Tor Forum](https://forum.torproject.net/)
- [Snowflake Documentation](https://snowflake.torproject.org/)
- [GitLab Issues](https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/-/issues)

## Next Steps

- [Review performance considerations](PERFORMANCE.md)
- [Set up monitoring](MONITORING.md)
- [Optimize your deployment](INSTALLATION.md)

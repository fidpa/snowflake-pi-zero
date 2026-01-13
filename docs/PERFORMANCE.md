# Performance Analysis

## WiFi Signal Impact on Connection Success

### Key Finding: Signal Strength Matters

Real-world deployment data shows **WiFi signal quality directly impacts WebRTC connection success rates**.

| Signal Strength | Connection Success Rate | Expected Clients/Hour |
|-----------------|------------------------|----------------------|
| -66 dBm (Good) | ~70% | 7-8 connections |
| -72 dBm (Fair) | ~30% | 3-4 connections |
| Difference | **2.3x improvement** | ~4 more connections |

### Why This Happens

**WebRTC is latency-sensitive**:
- WebRTC STUN/TURN handshake requires low latency (< 200ms ideal)
- Weak WiFi increases packet loss and retransmission delays
- Tor broker has ~20 second timeout for data channel establishment
- Poor signal = more timeouts = fewer successful connections

**NAT type is not the issue**: Both restrictive NAT and symmetric NAT work with Snowflake. The bottleneck is WiFi layer, not NAT traversal.

### Signal Quality Scale

```
-30 dBm  = Excellent (theoretical max)
-50 dBm  = Excellent
-60 dBm  = Good          ← Target for optimal performance
-67 dBm  = Good/Fair     ← Acceptable performance
-70 dBm  = Fair          ← Reduced effectiveness
-80 dBm  = Poor
-90 dBm  = Unusable
```

**6 dBm difference = ~4x signal power difference**

### Optimizing Signal Strength

1. **Move Device Closer to Router**
   - Target: -66 dBm or better
   - Test: `iw dev wlan0 link | grep signal`

2. **Router Placement**
   - Central location, elevated position
   - Avoid metal obstacles and microwaves

3. **Use 5 GHz Band** (if Pi supports)
   - Less congested
   - Better for short-range, high-bandwidth

4. **External Antenna** (Pi Zero limitation)
   - Pi Zero 2W has internal antenna only
   - Consider USB WiFi adapter with external antenna

5. **Ethernet Adapter** (best solution)
   - USB to Ethernet adapter
   - Eliminates WiFi variability completely

## Multi-Device Load Distribution

### Expected Behavior

**Unequal distribution is normal** when devices have different WiFi signal quality.

Example from real deployment:

| Device | Signal | Connections/Hour | Reason |
|--------|--------|-----------------|--------|
| Device A | -66 dBm | 7 connections | Good signal = fewer timeouts |
| Device B | -72 dBm | 4 connections | Fair signal = more timeouts |

**Total capacity utilized**: 11 connections/hour across 10 client slots (5 per device)

### Tor Broker Load-Balancing

**Confirmed working correctly**: Broker distributes equal number of SDP offers to all proxies.

**The difference is client-side**: WebRTC connection establishment succeeds more often on devices with better network conditions.

### When to Intervene

**Do nothing if**:
- Both devices are actively receiving traffic
- Total capacity is being utilized
- System is stable

**Consider action if**:
- One device has 0 connections for >24 hours
- WiFi signal consistently < -75 dBm
- Memory/CPU limits are being hit

**Solutions**:
- Improve WiFi signal (see above)
- Reduce capacity on weak device (5 → 3 clients)
- Accept unequal distribution (dual-proxy provides redundancy)

## Resource Constraints (Pi Zero 2W)

### Hardware Limitations

| Resource | Available | Snowflake Usage | Headroom |
|----------|-----------|----------------|----------|
| RAM | 512 MB | 15-40 MB per device | ~400 MB free |
| CPU | 4 cores @ 1 GHz | 2-10% per device | ~80% free |
| WiFi | 802.11n | 6-20 Mbps capped | Sufficient |

**Capacity tuning**:
- 5 clients = Normal (recommended for strong signal)
- 3 clients = Reduced (for weak signal or resource constraints)
- 10 clients = Too high (OOM kills likely)

### Memory Patterns

**Normal usage**:
- Initial: 15-20 MB
- With connections: 25-40 MB
- Peak (5 clients): 60-80 MB
- **Alert threshold**: > 120 MB

**If memory grows unbounded**: Memory leak, restart service.

### CPU Usage

**Normal usage**:
- Idle: 2-5%
- Active connections: 5-15%
- Peak (5 clients, high traffic): 20-30%

**CPU quota**: Limited to 30% in systemd service (prevents runaway)

### Temperature Impact

**Observation**: Pi Zero 2W thermal throttles at ~80°C

**Monitoring**:
```bash
# Check current temperature
vcgencmd measure_temp

# Check throttling status
vcgencmd get_throttled
```

**Cooling**: Passive heatsink sufficient for Snowflake workload

## Bandwidth Profiles

### Rationale for Time-Based Limiting

**Daytime** (09:00-00:00): **6 Mbps**
- Assumption: Shared network with other users
- Conservative limit to avoid impacting household traffic

**Nighttime** (00:00-09:00): **20 Mbps**
- Assumption: Low household network usage
- Higher limit allows more Tor traffic

### Real-World Traffic Patterns

**Highly variable per connection**:
- Minimum: 1 KB (failed handshake)
- Typical: 24-200 MB
- Maximum observed: 936 MB

**Daily total**: 2-5 GB across 10-12 connections

### Tuning Bandwidth Limits

**Increase limits if**:
- Fast internet connection (>100 Mbps)
- Dedicated device (not sharing network)
- Want to maximize Tor support

**Decrease limits if**:
- Slow internet connection (<20 Mbps)
- Network congestion issues
- ISP bandwidth caps

**Disable limits** (for dedicated high-bandwidth support):
```bash
sudo /opt/snowflake/tc-bandwidth-limiter.sh remove
```

## Scaling Considerations

### Single Device vs Fleet

| Setup | Total Capacity | Redundancy | Maintenance |
|-------|---------------|------------|-------------|
| 1 device | 5 clients | None | Simple |
| 2 devices | 10 clients | High | Moderate |
| 5+ devices | 25+ clients | Very high | Complex |

**Recommendation for home deployment**: 2 devices
- Provides redundancy (one can fail)
- Manageable maintenance overhead
- Sufficient capacity for meaningful Tor support

### Network Topology

**Best practice**: Dedicated network segment
- Prevents Snowflake traffic from impacting local devices
- Easier bandwidth management
- Optional: VLAN or separate router

**Monitoring at scale**: Centralized Prometheus + Grafana
- Single dashboard for all devices
- Alerting for fleet-wide issues

## Performance Benchmarks

### Expected Metrics (per device, 24h)

| Metric | Low | Normal | High |
|--------|-----|--------|------|
| Connections | 0-3 | 4-12 | 12-24 |
| Total Traffic | < 500 MB | 1-3 GB | 5-10 GB |
| Avg Connection | 10-50 MB | 100-500 MB | 1 GB+ |
| Uptime | < 90% | 95-99% | 99.9% |

**Note**: "Low" connections is not necessarily a problem - Tor demand fluctuates.

### Baseline Verification

Run for 7 days, then check:

```bash
# Total connections in last week
grep "connections" /var/log/snowflake/snowflake-proxy.log | grep -E "$(date -d '7 days ago' +%Y-%m-%d)" | wc -l

# Average memory
ps -C snowflake-proxy -o rss= | awk '{print $1/1024 " MB"}'

# Service uptime
systemctl status snowflake-proxy.service | grep "Active:"
```

**Compare to baselines above**. If significantly lower, investigate WiFi, NAT, or firewall issues.

## Advanced Optimization

### Prioritize Snowflake Traffic (QoS)

Use `iptables` + `tc` for traffic prioritization:

```bash
# Mark Snowflake traffic (UDP, destination port range 1024-65535)
sudo iptables -t mangle -A OUTPUT -p udp -j MARK --set-mark 1

# Prioritize marked traffic
sudo tc qdisc add dev wlan0 root handle 1: htb default 12
sudo tc class add dev wlan0 parent 1: classid 1:1 htb rate 20mbit
sudo tc class add dev wlan0 parent 1:1 classid 1:10 htb rate 15mbit ceil 20mbit prio 1
sudo tc filter add dev wlan0 parent 1: protocol ip prio 1 handle 1 fw flowid 1:10
```

**Caution**: Advanced networking, test thoroughly.

### Reduce Connection Timeout

Edit systemd service to experiment with longer summary intervals:

```bash
ExecStart=/opt/snowflake/snowflake-proxy -capacity 5 -summary-interval 10m -verbose
```

**Effect**: Fewer frequent small connections, more sustained longer connections.

## Next Steps

- [Review troubleshooting guide](TROUBLESHOOTING.md)
- [Optimize monitoring setup](MONITORING.md)
- [Join Tor community discussions](https://forum.torproject.net/)

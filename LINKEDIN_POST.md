🌐 Tor Snowflake Proxy auf Pi Zero: Tech for Social Good trifft Production Monitoring

Anlass: Im Iran blockiert das Regime das Internet während der Proteste. Der WDR berichtet über Tor Snowflake als eine Möglichkeit, Menschen dort unzensierten Netzzugang zu ermöglichen.

Meine Reaktion: Installation auf zwei Pi Zeros, die bisher nur über Sensoren Umweltdaten in meiner Wohnung erfassten.

🔧 Was hinter dem production-ready deployment steckt:
• systemd-Services mit automatischem Restart
• Bandwidth-Limiting via tc-netem
• Metrics-Export → Prometheus → Grafana Dashboard
• Telegram-Alerting bei Ausfällen

💡 Warum Pi Zeros statt meinem leistungsstärkeren Pi 5?
Bewusste Trennung: Kritische Infrastruktur (Router, Failover) bleibt geschützt, während ich an zwei Proxies Load Balancing in der Praxis erprobe.

📊 Das Ergebnis nach 24 Stunden:
• ~11 Verbindungen/Stunde
• 2+ GB Datenverkehr für freien Internetzugang
• 100% Uptime dank automatisiertem Monitoring

Die Realität: Bei kompletter Internet-Sperre hilft kein Proxy. Aber ich betrachte das grundsätzlich als unterstützenswert und technisch ist es eine spannende Herausforderung, die beim Aufbau von Deployment-Routine hilft.

🔗 GitHub: https://lnkd.in/dMksvVsz

Marc | IT · Datenschutz · Psychologie

# TechForGood #SelfHosting #RaspberryPi #DevOps #Monitoring #Prometheus #Grafana #TorNetwork

#!/usr/bin/env python3
"""Generates platform/observability/extras/dashboard.yaml (a Grafana dashboard ConfigMap)."""
import json, textwrap

PROM = {"type": "prometheus", "uid": "prometheus"}
LOKI = {"type": "loki", "uid": "loki"}

def ts(pid, title, expr, x, y, unit=None, legend="{{service}}"):
    return {
        "id": pid, "type": "timeseries", "title": title, "datasource": PROM,
        "gridPos": {"x": x, "y": y, "w": 12, "h": 8},
        "fieldConfig": {"defaults": ({"unit": unit} if unit else {}), "overrides": []},
        "targets": [{"refId": "A", "expr": expr, "legendFormat": legend, "datasource": PROM}],
    }

panels = [
    ts(1, "Request rate by service", 'sum by (service) (rate(http_requests_total[5m]))', 0, 0, "reqps"),
    ts(2, "5xx ratio by service",
       'sum by (service) (rate(http_requests_total{status=~"5.."}[5m])) / sum by (service) (rate(http_requests_total[5m]))',
       12, 0, "percentunit"),
    ts(3, "p95 latency by service",
       'histogram_quantile(0.95, sum by (le, service) (rate(http_request_duration_seconds_bucket[5m])))',
       0, 8, "s"),
    ts(4, "Requests by status code", 'sum by (status) (rate(http_requests_total[5m]))', 12, 8, "reqps", "{{status}}"),
    ts(5, "Container restarts (1h)",
       'sum by (pod) (increase(kube_pod_container_status_restarts_total{namespace="banking"}[1h]))',
       0, 16, None, "{{pod}}"),
    ts(6, "Top 10 pods by memory",
       'topk(10, sum by (pod) (container_memory_working_set_bytes{namespace="banking", container!=""}))',
       12, 16, "bytes", "{{pod}}"),
    {
        "id": 7, "type": "logs", "title": "Warnings and errors (Loki)", "datasource": LOKI,
        "gridPos": {"x": 0, "y": 24, "w": 24, "h": 10},
        "options": {"showTime": True, "wrapLogMessage": True, "sortOrder": "Descending"},
        "targets": [{"refId": "A", "datasource": LOKI, "queryType": "range",
                     "expr": '{namespace="banking"} | json | level=~"error|warn"'}],
    },
]

dash = {
    "uid": "banking-overview", "title": "Banking Platform Overview", "tags": ["banking"],
    "schemaVersion": 39, "version": 1, "refresh": "30s",
    "time": {"from": "now-1h", "to": "now"}, "panels": panels,
}

body = textwrap.indent(json.dumps(dash, indent=2), "    ")
out = f"""apiVersion: v1
kind: ConfigMap
metadata:
  name: banking-overview-dashboard
  namespace: observability
  labels:
    grafana_dashboard: "1"
data:
  banking-overview.json: |
{body}
"""
open("platform/observability/extras/dashboard.yaml", "w").write(out)
print("wrote platform/observability/extras/dashboard.yaml")

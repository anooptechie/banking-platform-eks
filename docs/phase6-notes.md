# Phase 6 notes: observability (metrics, logs, traces, alerts)

- Stack, all ArgoCD apps (multi-source: chart + values files from Git): kube-prometheus-stack, Loki (single binary,
  filesystem), Tempo, Grafana Alloy (log collector), OpenTelemetry Collector, plus an extras app (ServiceMonitor,
  PrometheusRule, dashboard ConfigMap, Alloy RBAC). Values were validated offline with `helm template` before any cluster time.
- Metrics: every service serves /metrics (default Prometheus registry); one ServiceMonitor scrapes all backends
  (frontend excluded: nginx would serve the SPA). Targets up: <fill in, expect 31>. honorLabels is required because the
  app's own `service` label otherwise collides with the Kubernetes one and becomes exported_service.
- Logs: Alloy tails pod logs through the Kubernetes API into Loki; all 32 workloads had logs in Loki. Promtail is end-of-life,
  so it was not used. The Loki and Tempo charts now live in the grafana-community repo.
- Traces: services export OTLP to a collector, which forwards traces to Tempo and drops the duplicate OTel metrics
  (Prometheus already scrapes /metrics). Trace -> logs works: "Logs for this trace" opens Loki filtered to the trace_id.
- Finding 1: traces are per service. A gateway request shows 1 service / 1 span, so the gateway's proxy does not propagate
  trace context to backends. Most traces in Tempo are Kubernetes health probes (/healthz, /readyz); a collector filter
  processor would drop them. Both are known follow-ups, not fixed.
- Alerts: BankingDeploymentUnavailable, BankingPodCrashLooping, BankingScrapeTargetDown, BankingHigh5xxRatio,
  BankingHighLatencyP95. Test: scaled account-service to 0 and generated traffic; BankingDeploymentUnavailable fired for
  account-service and BankingHigh5xxRatio (about 13% at the gateway) went pending then firing; both reached Alertmanager.
- Finding 2: scaling a deployment down is undone by ArgoCD self-heal. With App-of-Apps, pausing GitOps for a chaos test
  means pausing BOTH the parent (root) and the child (banking-platform), or the parent re-enables the child.
- Finding 3: a scaled-to-zero service has no scrape target, so `up == 0` never fires; the deployment-availability rule from
  kube-state-metrics is the right signal.
- Cardinality check (count of distinct `path` label values): <fill in>.
- Apply: 15m12s. Destroy: 11m58s. Teardown also removes the observability namespace PVCs (Loki).

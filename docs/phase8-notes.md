# Phase 8 notes: highly available Postgres, backups and the restore drill

- Database: CloudNativePG (operator 1.30.2) with a 3-instance cluster (banking-pg), one pod per availability zone,
  gp3 volumes. The apps use the read-write service banking-pg-rw; no application code changed. cert-manager is required
  by the Barman Cloud plugin (v0.16.0). The S3 bucket and the DB password (SSM) live outside the ephemeral stack so they
  survive teardown; IRSA gives the Postgres pods S3 access through a fixed-name role.
- Backups: continuous WAL archiving plus base backups (immediate and every 6 hours) to S3 through the Barman Cloud plugin.
- Failover test: forced deletion of the primary during a 5-requests-per-second probe through the NLB.
  banking-pg-2 was promoted automatically; the old primary rejoined as a replica; the cluster returned to healthy 3/3.
  29 of 322 requests failed (14 x 500, 13 x 502, 2 timeouts), first failure 3 s after the kill, last 28 s after.
  Replication is asynchronous by default, so a crash can lose the last few milliseconds of writes;
  postgresql.synchronous would trade latency for zero data loss.
- Restore drill: the entire cluster was destroyed, then rebuilt from nothing (Terraform + bootstrap + ArgoCD).
  terraform apply 14m20s; bootstrap 1m26s; database restored from the S3 base backup and WAL, 3 instances healthy;
  app serving the restored data about 19 minutes after the bootstrap began (upper bound; precise primary-ready time: <fill in>).
  Row counts of every table were IDENTICAL to the baseline taken before the loss (docs/baseline-rowcounts.txt),
  and the original application user could log in and see their accounts.
- The WAL archive records the history: timeline 1 (original cluster), timeline 2 (failover promotion),
  timeline 3 (restored cluster), archived under the new server name banking-pg-g1.
- Lesson 1: a cluster must never archive into a prefix that already holds another cluster's archive; each restore reads
  the previous generation and writes a new one (scripts/next-generation.sh automates it).
- Lesson 2: the database password has to survive teardown (SSM), otherwise the restored roles keep the old password
  hash and the application cannot connect.
- Lesson 3: a pasted block of terminal output executes as commands; copy commands, not their output.
- Known follow-ups: synchronous replication, backup retention beyond 7 days, scheduled restore tests,
  PodDisruptionBudgets and a connection pooler (PgBouncer) in front of the 31 services.

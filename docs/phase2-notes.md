# Phase 2 notes: VPC and EKS with Terraform

- Region us-east-1, 3 AZs, one NAT gateway (cost; production would use one per AZ).
- terraform-aws-modules vpc (~> 6.0) and eks (~> 21.0); Kubernetes 1.36; AWS provider 6.x.
- Managed node group: 3 x t3.large, AL2023. Add-ons: vpc-cni, kube-proxy, coredns, eks-pod-identity-agent, aws-ebs-csi-driver.
- EBS CSI uses EKS Pod Identity (no IRSA, no static keys).
- Apply time: <fill in>. Destroy time: 11m54s.
- Verified: 3 nodes Ready, system pods Running, a gp3 PVC bound and a pod wrote/read data.
- The ebs-csi-controller restarted 4 times during first start (identity not ready yet), then stabilized.
- Cluster ships with only a gp2 StorageClass and no default; a default gp3 class is created in Phase 4.
- Teardown verified: <fill in what you checked in the console>.

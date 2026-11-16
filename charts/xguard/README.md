 <p align="center">
    <img src="docs/header.png" alt="xguard">
 </p>

# XGuard Helm chart

This Helm chart can be used to deploy the whole [XGuard](https://xguard.local/) stack:

- XGuard Core service
- Postgres database
- XGuard Gateway service 
- public XGuard Proxy service

Check our [documentation](https://docs.xguard.local/deployment-strategies/kubernetes) for deployment
instructions.

XGuard Core runs as a single instance. Keep `replicaCount: 1` and
`autoscaling.enabled: false`; the chart rejects values that would run multiple Core replicas.

## ⚠️ Important: Postgres image tags 

Due to changes in Bitnami policy the Postgres subchart now uses the `latest` tag by default.
Remember to set a specific tag in your `values.yaml` to avoid issues with major version upgrades in production environments.

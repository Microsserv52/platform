---
icon: lucide/clipboard-check
---

# Delivery evidence

The course delivery must be documented on GitHub and reviewed by the group.
This page is the index for the evidence that should accompany the final
submission.

## Required evidence

- [ ] Contributors and service ownership.
- [ ] Architecture diagram and repository map.
- [ ] API contracts and examples.
- [ ] Local setup and deployment runbook.
- [ ] AWS account, region and resource inventory without secrets.
- [ ] EKS topology and Kubernetes manifests or commands.
- [ ] CI/CD pipeline runs and rollback procedure.
- [ ] Load-test scenarios, raw results and interpretation.
- [ ] Bottleneck investigation and before/after comparison.
- [ ] Cost estimate, actual spend and PaaS decisions.
- [ ] SLO/SLA definitions and observability dashboards.
- [ ] Test strategy and final verification.
- [ ] Known limitations and future work.

## Staging backlog — not implemented

- [ ] Implement and accept the [developer-only staging plan](../infrastructure/staging.md):
      fixed small copies of all production business services, scheduled availability,
      synthetic seed data, Cloudflare Access, separate Grafana Cloud observability,
      Faro errors enabled and Umami/usage analytics disabled.
- [ ] Record the approved budget/schedule, hosting/parity tradeoffs, isolation
      tests, independent telemetry gates, recovery/rollback and operating evidence.

These items are TODO; documenting the plan does not complete them.

## AI disclosure

The course permits limited AI assistance for tasks such as boilerplate,
improvements and error fixing. The delivery must state:

- which artifacts or code were assisted by AI;
- what prompts or task descriptions were used when relevant;
- what the group reviewed, tested and changed;
- which parts were implemented directly by group members.

Every group member must understand and be able to defend the complete project,
including AI-assisted work.

## Reproducibility

For each claim, link to a commit, pull request, workflow run, dashboard export,
load-test report or command output. Include the date, environment and version.
Never include credentials, private tokens or personal data in evidence.

# Architecture

## Goals

Build an AWS network where a "Shared Services" VPC hosts an F5
Distributed Cloud Secure Mesh Site v2 (SMSv2) Customer Edge (CE). The CE's
job is to discover public DNS origins and publish load-balanced VIPs that
are reachable from other VPCs over a Transit Gateway (TGW) - without using
F5's legacy orchestrated site types (`AWS VPC Site`, `AWS TGW Site`), and
without F5's Cloud Connect GRE-to-TGW automation (which is also tied to
the orchestrated AWS TGW Site type). Instead, the CE is deployed as a
plain SMSv2 site (`not_managed {}`) onto AWS resources we build and
control directly in Terraform, and it peers with the Transit Gateway using
AWS's third-party tunnel-termination capability via an F5XC External
Connector object (see the stub module and ADR 0003 for current status).

## The four VPCs

| Role | VPC | Purpose |
|---|---|---|
| Spoke | Client A | Represents a typical application/workload VPC that needs to reach services published via the CE. |
| Spoke | Client B | Same as Client A - a second, independent workload VPC. |
| Hub | Shared Services | Hosts the F5 CE. Dual-homed: SLO (outside, Internet-facing) + SLI (inside, TGW-facing). |
| Spoke | On-Prem Mimic | Simulates an on-premises site advertising two private ranges (a Class B and a Class C) into the Transit Gateway, the way a real on-prem router/firewall might via BGP or static routes over a VPN/Direct Connect. |

We picked a **single region** (`us-east-2`) and, for this iteration, a
**single Availability Zone** (`us-east-2a`) across all four VPCs. See
[ADR 0001](decisions/0001-single-az-vs-multi-az.md) for the tradeoffs of
that choice and what changes if/when we go multi-AZ.

## Addressing

See the CIDR table in the top-level `README.md`. Two things worth calling
out:

1. **The Shared Services VPC's single `/26` is split into two `/27`s** -
   one for the CE's SLO interface (outside, gets the Elastic IP and
   Internet route), one for its SLI interface (inside, faces the TGW
   attachment). This mirrors F5's dual-interface SMSv2 pattern exactly as
   documented for AWS ClickOps deployments.
2. **The On-Prem Mimic VPC carries two CIDR blocks** (a `/16` Class B
   primary and a `/24` Class C secondary, associated via
   `aws_vpc_ipv4_cidr_block_association`) to simulate a site that
   advertises more than one private range - a common real-world on-prem
   pattern (e.g., a legacy `172.16.0.0/16` data center range plus a
   smaller `192.168.50.0/24` management range).

## Routing model

See [ADR 0002](decisions/0002-tgw-routing-design.md) for the full
route-table-by-route-table breakdown. In short: **hub-and-spoke with
spoke isolation.** Client A, Client B, and the On-Prem Mimic VPC can each
only reach the Shared Services VPC over the TGW; they cannot reach each
other directly. The Shared Services VPC (and therefore the CE) can reach
all three. All inter-VPC ("east-west") traffic is therefore forced
through the CE's position in the Shared Services VPC, which is the whole
point of putting F5 there: it discovers origins in the spokes and
publishes VIPs that the spokes reach only via the hub.

## Internet egress

Per the current design decision, all four VPCs have their own Internet
Gateway and a `0.0.0.0/0` route independent of the F5 path - this
simplifies initial bring-up (SSM/yum package access, SSH troubleshooting,
CE registration with F5 Regional Edges) and makes early
connectivity-testing easier to debug (you can rule out "no Internet at
all" vs. "TGW routing is wrong" independently). Once the F5-published-VIP
path is validated end-to-end, consider removing the direct
`0.0.0.0/0 -> IGW` routes from Client A and Client B's route tables (they
would then only reach the Internet indirectly, if the CE is configured to
forward proxy for them) to force all traffic - not just east-west - through
the CE. This is a deliberate "loosen now, tighten later" sequencing
choice, not an oversight.

## F5 CE deployment specifics

- **SMSv2, single-node, `not_managed {}`** - see ADR 0001 for why
  single-node rather than the 3-node HA model, and
  `PROJECT_INSTRUCTIONS.md` for why `not_managed` (as opposed to the
  legacy orchestrated site types) is a firm project constraint.
- **Marketplace AMI via the F5-published SSM parameter**
  (`/aws/service/marketplace/prod-wrwzhcymymama/latest`), not the
  downloaded `.vhd.gz` + `vmimport` path - simpler in Terraform, at the
  cost of requiring a one-time AWS Marketplace subscription per
  account/region.
- **`m5.2xlarge`**, F5's documented minimum supported instance size for a
  CE node, and an **80 GB** root volume (F5's documented minimum).
- **Fully automated token flow**: Terraform creates the
  `volterra_securemesh_site_v2` object, then a `volterra_token` tied to
  it, then feeds that token into the CE instance's cloud-init user-data -
  no manual "copy token from Console" step. This mirrors the pattern used
  in an existing internal GCP SMSv2 Terraform example, adapted for AWS's
  dual-ENI + Elastic IP model.
- **Static SLO IP pinned via cloud-init**, computed from the actual
  AWS-assigned ENI private IP (rather than the person picking an IP by
  hand) - this keeps the CE's own understanding of its SLO address in
  lockstep with the ENI Terraform created, which matters because F5 does
  not allow the SLO IP to change after the site registers.
- **`source_dest_check = false`** on both ENIs - required for any network
  virtual appliance (NVA) that needs to route traffic not addressed to
  itself, which is exactly what the CE's SLI interface does for TGW
  traffic.

## What's intentionally NOT built yet

- The F5XC **External Connector** object and whatever AWS-side resource
  represents third-party IPsec/tunnel termination directly on the
  Transit Gateway. See
  [ADR 0003](decisions/0003-external-connector-status.md) and
  `modules/f5xc-external-connector/README.md`.
- GitHub Actions CI/CD (`.github/workflows/` is a placeholder).
- Any actual HTTP/TCP Load Balancer or Origin Pool objects on the CE - out
  of scope for this phase; the person building this out already has a
  plan for that layer.

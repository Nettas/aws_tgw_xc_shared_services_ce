# aws-tgw-xc-sharedservice-ce

Terraform to build a 4-VPC AWS network hub-and-spoke architecture, connected
by a Transit Gateway, with an F5 Distributed Cloud Secure Mesh Site v2
(SMSv2) Customer Edge deployed in a "Shared Services" VPC that discovers
public DNS origins and publishes VIPs reachable by the other VPCs over the
Transit Gateway.

> **Status:** Networking (VPCs, Transit Gateway, routing) and the F5 CE
> node are fully built out here. The F5XC **External Connector** peering
> to the Transit Gateway (AWS's newer third-party tunnel-termination
> capability) is a **stub module** pending confirmation of its current
> Terraform resource schema - see
> [`modules/f5xc-external-connector/README.md`](modules/f5xc-external-connector/README.md)
> and [`docs/decisions/0003-external-connector-status.md`](docs/decisions/0003-external-connector-status.md).

## Architecture at a glance

```
                         ┌───────────────────────────────┐
                         │   Shared Services VPC          │
                         │   10.0.0.128/26 (us-east-2a)    │
                         │                                 │
                         │   ┌─────────┐     ┌─────────┐  │
                         │   │  SLO    │     │  SLI    │  │
                         │   │/27 +IGW │     │/27      │  │
                         │   │+EIP     │     │         │  │
                         │   └────┬────┘     └────┬────┘  │
                         │        │ F5 CE (SMSv2)  │       │
                         │        │ single node    │       │
                         └────────┼────────────────┼───────┘
                                  │ (Internet,      │ (TGW attachment,
                                  │  RE tunnels)     │  rtb-shared-services)
                                  │                  │
                                  ▼                  ▼
                          F5 Distributed        ┌──────────────┐
                          Cloud Regional        │  Transit GW   │
                          Edges                 │  us-east-2    │
                                                 └──┬────┬────┬─┘
                          ┌──────────────────────────┘    │    └───────────────────────┐
                          │                                │                            │
                 ┌────────▼────────┐             ┌─────────▼────────┐         ┌─────────▼──────────┐
                 │  Client A VPC    │             │  Client B VPC     │         │  On-Prem-Mimic VPC  │
                 │  10.0.0.0/26     │             │  10.0.0.64/26     │         │  172.16.0.0/16 (B)  │
                 │  rtb-client-a    │             │  rtb-client-b      │         │  192.168.50.0/24 (C) │
                 │  1x AL client    │             │  1x AL client      │         │  rtb-onprem-mimic    │
                 └──────────────────┘             └────────────────────┘         │  1x AL "on-prem" host│
                                                                                   └──────────────────────┘
```

Each spoke (Client A, Client B, On-Prem-Mimic) can reach **only** the
Shared Services VPC over the Transit Gateway - never each other directly.
The Shared Services VPC can reach all three spokes. This forces all
east-west traffic through the CE, which is the point of the design: the
CE discovers origins and publishes VIPs that the spokes can only get to
via the hub. See
[`docs/decisions/0002-tgw-routing-design.md`](docs/decisions/0002-tgw-routing-design.md)
for the full route-table-by-route-table breakdown.

## CIDR plan

| VPC | CIDR(s) | Subnets | AZ |
|---|---|---|---|
| Client A | `10.0.0.0/26` | `workload` = `10.0.0.0/26` | us-east-2a |
| Client B | `10.0.0.64/26` | `workload` = `10.0.0.64/26` | us-east-2a |
| Shared Services | `10.0.0.128/26` | `slo` = `10.0.0.128/27`, `sli` = `10.0.0.160/27` | us-east-2a |
| *(reserved, unused)* | `10.0.0.192/26` | - | - |
| On-Prem Mimic | `172.16.0.0/16` (Class B) + `192.168.50.0/24` (Class C) | `classb` = `172.16.0.0/24`, `classc` = `192.168.50.0/24` | us-east-2a |

## Repository structure

```
.
├── README.md                          <- you are here
├── PROJECT_INSTRUCTIONS.md            <- contributor/operator playbook
├── docs/
│   ├── architecture.md                <- deeper design writeup
│   └── decisions/                     <- lightweight ADRs
│       ├── 0001-single-az-vs-multi-az.md
│       ├── 0002-tgw-routing-design.md
│       └── 0003-external-connector-status.md
├── bootstrap/                         <- one-time: creates the S3+DynamoDB state backend
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── environments/
│   └── single/                        <- the one (and, for now, only) environment
│       ├── versions.tf
│       ├── backend.tf
│       ├── providers.tf
│       ├── variables.tf
│       ├── locals.tf                  <- CIDR plan lives here
│       ├── vpc.tf                     <- the 4 VPCs + their subnet routing
│       ├── tgw.tf                     <- Transit Gateway, attachments, route tables
│       ├── security-groups.tf         <- client-node security groups
│       ├── compute.tf                 <- client nodes + F5 CE + external connector
│       ├── outputs.tf
│       └── terraform.tfvars.example
├── modules/
│   ├── vpc/                           <- generic VPC + per-subnet route tables
│   ├── tgw/                           <- Transit Gateway resource only
│   ├── client-node/                   <- Amazon Linux 2023 test instance
│   ├── f5xc-ce-site/                  <- F5 SMSv2 Shared Services CE (fully automated)
│   └── f5xc-external-connector/       <- STUB - see its README before relying on it
└── .github/workflows/                 <- reserved for CI; intentionally empty for now
```

## Prerequisites

1. An AWS account/credentials with permission to create VPCs, EC2, TGW,
   IAM roles, S3, and DynamoDB resources in `us-east-2`.
2. A subscription to the **F5 Distributed Cloud CE** listing in AWS
   Marketplace for this account/region (required before the Marketplace
   AMI SSM parameter lookup will succeed).
3. An F5 Distributed Cloud tenant, with an API client certificate (`.p12`)
   generated from **Console > Administration > API Credentials**.
4. Terraform >= 1.7.0.
5. An existing S3 bucket name you'll use for state (created by
   `bootstrap/`, see below) - bucket names are global across AWS, so pick
   something unique.

## Getting started

### 1. Bootstrap the state backend (one-time)

```bash
cd bootstrap
terraform init
terraform apply -var="state_bucket_name=YOUR-UNIQUE-BUCKET-NAME"
```

Note the `state_bucket_name` and `lock_table_name` outputs, then update
`environments/single/backend.tf` with the real bucket name (the
`dynamodb_table` default already matches `bootstrap`'s default
`lock_table_name`).

### 2. Configure the environment

```bash
cd environments/single
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: mgmt_allowed_cidrs, f5xc_api_url, f5xc_api_p12_file, etc.
```

### 3. Deploy

```bash
terraform init
terraform plan
terraform apply
```

This single `apply` will:
- Create all four VPCs and their subnets/route tables.
- Create the Transit Gateway, its four attachments, four route tables,
  and the associations/propagations described above.
- Launch the three Amazon Linux client/on-prem-mimic test nodes.
- Create the F5XC Secure Mesh Site v2 object, a registration token, and
  the CE's EC2 instance with cloud-init user-data that consumes that
  token automatically - no manual "generate token, paste into console"
  step required.

### 4. What's NOT yet automated

The F5XC **External Connector** object and the AWS-side third-party TGW
tunnel-termination attachment are stubbed - see
[`modules/f5xc-external-connector/README.md`](modules/f5xc-external-connector/README.md)
for exactly what's missing and why, and what to confirm before filling it
in.

## CI/CD

GitHub Actions workflows are intentionally not wired up yet
(`.github/workflows/` is a placeholder) - per current project sequencing,
we're getting the Terraform working correctly by hand first, then adding
`fmt`/`validate`/`plan`-on-PR and `apply`-on-merge automation once the
happy path is proven out.

## Security notes

- `mgmt_allowed_cidrs` should be scoped tightly (your IP or VPN egress),
  never left at `0.0.0.0/0`.
- The F5XC `.p12` API credential and `terraform.tfvars` are both
  gitignored - never commit them.
- Client VPCs currently have their own Internet Gateway egress
  independent of the F5 CE path (per current design decision, to simplify
  initial bring-up/troubleshooting). You may want to remove that direct
  egress once the F5-published-VIP path is validated, to force all
  outbound traffic through the CE - see
  [`docs/architecture.md`](docs/architecture.md).

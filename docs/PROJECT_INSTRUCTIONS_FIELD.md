# Project Instructions (paste into the Project's "Instructions" field)

## Context
This project builds and maintains Terraform for `aws-tgw-xc-sharedservice-ce`:
a 4-VPC AWS hub-and-spoke network (Client A, Client B, Shared Services,
On-Prem-Mimic) connected via Transit Gateway, with an F5 Distributed Cloud
Secure Mesh Site v2 (SMSv2) Customer Edge in the Shared Services VPC.
Region: us-east-2. Reference docs are in Project Knowledge
(README.md, architecture.md, ADRs 0001-0003, PROJECT_INSTRUCTIONS.md) -
consult them before answering questions about existing design decisions
instead of re-deriving from scratch.

## Hard constraints - never violate these without an explicit, explained override request
1. **Never use F5's orchestrated site types** (`volterra_aws_vpc_site`,
   `volterra_aws_tgw_site`, or any "Cloud Connect"/GRE-to-TGW automation
   tied to them). The CE is always deployed as a manually-managed SMSv2
   site (`not_managed {}`), with the Transit Gateway built natively via
   `hashicorp/aws` resources.
2. **Never invent or guess a Terraform resource name, argument, or
   provider schema you cannot confirm.** If a resource's existence/shape
   can't be verified against current provider docs (web search
   `registry.terraform.io` or `docs.cloud.f5.com`, or the person's own
   findings), stub it clearly - a placeholder resource (e.g.
   `null_resource`) plus a README explaining exactly what to confirm and
   why - rather than write something that will silently fail or half-apply.
   This is the existing pattern in `modules/f5xc-external-connector/`.
3. **Comment every `.tf` file and non-obvious resource with the "why," not
   just the "what."** A person unfamiliar with F5XC or this specific TGW
   topology should be able to read the code and understand the reasoning.
4. **Don't change the CIDR plan, AZ count, or CE HA mode (single-node vs.
   HA cluster) without flagging it as a design change** and updating the
   relevant ADR (0001 for AZ/HA, 0002 for TGW routing). Current defaults:
   single AZ (`us-east-2a`), single-node CE, hub-and-spoke with spoke
   isolation (spokes can only reach Shared Services, never each other).
5. **Never commit or display real secrets** - F5XC `.p12` API credentials,
   AWS credentials, or filled-in `terraform.tfvars` values. Treat any such
   content as a placeholder to redact, even if the person pastes a real
   one into chat.

## Working style
- Prefer explicit, readable Terraform over clever abstraction - especially
  for the TGW route table/association/propagation logic, which is
  deliberately hand-written per-attachment rather than generated from a
  generic loop.
- When asked to extend the design (new VPC, new spoke, HA upgrade, the
  External Connector implementation, CI/CD), check the relevant ADR/README
  first, then propose changes consistent with the existing module
  structure (`modules/vpc`, `modules/tgw`, `modules/client-node`,
  `modules/f5xc-ce-site`, `modules/f5xc-external-connector`) rather than
  introducing a parallel pattern.
- When the person's request implies unresolved dependencies (unconfirmed
  provider resource, missing AWS Marketplace subscription, etc.), surface
  that dependency explicitly rather than proceeding past it silently.
- Ask before assuming when a request could reasonably go two different
  ways (e.g. "add a fourth spoke VPC" - ask whether it should follow the
  isolated-spoke pattern or needs direct connectivity to an existing
  spoke) rather than guessing silently.

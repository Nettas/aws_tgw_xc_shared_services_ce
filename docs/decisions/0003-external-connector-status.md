# ADR 0003: F5XC External Connector / third-party TGW tunnel termination is stubbed

## Status

Accepted as a temporary gap. Must be resolved before this design is
considered "done."

## Context

The project explicitly rules out F5's legacy **orchestrated AWS TGW
Site** (`volterra_aws_tgw_site`), which would otherwise handle CE-to-TGW
connectivity (via a GRE tunnel from the CE's SLI interface, automated by
F5's "Cloud Connect" framework) as part of F5 provisioning and managing
the Transit Gateway itself. Instead, this design:

- Builds the Transit Gateway natively in Terraform (`hashicorp/aws`
  resources only), giving us full, explicit control over the route
  table/attachment/propagation topology described in ADR 0002.
- Deploys the CE as a manually-managed SMSv2 site (`not_managed {}`).
- Intends to connect the two using F5's **External Connector** object
  together with AWS's newer capability for **third-party appliances to
  terminate tunnels directly on the Transit Gateway** (rather than via a
  VPC attachment + GRE-to-SLI, which is the Cloud Connect pattern tied to
  the orchestrated TGW site type).

## Why this is stubbed rather than implemented

At the time this repo was created, the official `volterraedge/volterra`
Terraform provider's public documentation does not show a resource for
the External Connector object, and the AWS-side construct for third-party
TGW tunnel termination is new enough that its exact Terraform resource
shape (whether it's a variant of `aws_ec2_transit_gateway_connect` +
`aws_ec2_transit_gateway_connect_peer`, or something else entirely) could
not be confirmed against current provider docs during this build.

Per this project's operating principle (see `PROJECT_INSTRUCTIONS.md`,
"never guess at unconfirmed resource schemas"), we did not fabricate a
resource block for either side of this connection. `modules/f5xc-external-connector`
is a stub with a `null_resource` placeholder and a detailed `README.md`
explaining exactly what needs to be confirmed and filled in.

## What "done" looks like

1. Confirm the current F5XC Terraform resource for External Connectors
   (either from updated `volterraedge/volterra` provider docs, or via
   `terraform import` after creating one manually via ClickOps once, then
   inspecting the imported resource type/attributes).
2. Confirm the current AWS resource(s) for third-party TGW tunnel
   termination - check whether it's exposed as a variant of the existing
   `aws_ec2_transit_gateway_connect`/`connect_peer` resources in the
   `hashicorp/aws` provider, or a newer resource type entirely.
3. Fill in `modules/f5xc-external-connector/main.tf` for real, wire its
   inputs/outputs to match, and remove the "STUB" framing from its
   `README.md`, this ADR's status line, and the top-level `README.md`.
4. Validate end-to-end: confirm the CE can discover an origin in, say,
   Client A, and that a published VIP is reachable from Client B purely
   through the TGW/External-Connector path (not just through the
   already-working plain VPC-attachment routing this repo already builds).

## Consequences of leaving this stubbed for now

- `terraform apply` against `environments/single` will succeed today and
  stand up a fully working VPC/TGW/CE skeleton, but the CE will not
  actually be peered to the Transit Gateway for data-plane purposes yet -
  only the native AWS routing described in ADR 0002 exists today. Origin
  discovery and VIP publishing that depend on the External Connector path
  specifically will not work until this ADR is resolved.
- Anyone picking up this repo should treat "the networking works" and
  "the F5 data plane is peered to it" as two separate claims, and check
  this ADR's status before assuming the latter.

# f5xc-external-connector (STUB MODULE - ACTION REQUIRED)

## What this module is for

This module is meant to create the F5 Distributed Cloud **External
Connector** object that peers the Shared Services CE (Secure Mesh Site v2)
with the AWS Transit Gateway using AWS's third-party IPsec tunnel
termination-to-TGW capability, as an alternative to F5's legacy
orchestrated **AWS TGW Site**. Per your explicit design decision, this repo
does **not** use `volterra_aws_tgw_site` (the older, F5-orchestrated TGW
site type) - it uses the manually-created SMSv2 Shared Services site plus
a native AWS Transit Gateway, connected via the External Connector /
third-party tunnel termination path instead.

## Why this is a stub

As of this repo's creation, the official `volterraedge/volterra` Terraform
provider (the same one used for `volterra_securemesh_site_v2` and
`volterra_token` elsewhere in this repo) does not have publicly documented
resources for the External Connector object or for AWS's third-party
Transit Gateway tunnel-termination attachment. Both are newer features
than what's reflected in current provider documentation at the time this
module was written. Rather than guess at a resource name/schema that may
not exist (which would silently fail or, worse, apply something
incorrect), this module intentionally stops short of that resource.

## What you need to do before this module is "done"

1. In F5 Distributed Cloud Console, go to **Multi-Cloud Network Connect >
   Manage > Networking > External Connectors** (or the current equivalent
   path - console navigation moves between releases) and either:
   - Create the External Connector via ClickOps once, then run
     `terraform import` against whatever resource the provider exposes for
     it (check `terraform providers schema -json` against your pinned
     provider version), or
   - Confirm the exact resource name/schema from F5's current docs/API
     reference and tell me (or your team) so `main.tf` here can be filled
     in properly.
2. On the AWS side, confirm the exact resource/attachment type AWS uses
   for third-party tunnel termination on the Transit Gateway (this may be
   a `aws_ec2_transit_gateway_connect` + `aws_ec2_transit_gateway_connect_peer`
   pair, or a newer construct depending on when you're reading this -
   the feature was very recently released relative to this repo's
   creation). The variables below are written to be resource-agnostic so
   they can be wired into whichever resource turns out to be correct.
3. Delete this README's "ACTION REQUIRED" framing once the module is
   filled in for real, and move the notes above into
   `docs/decisions/0003-external-connector-status.md` as a historical
   record.

## What IS safely automated elsewhere in this repo

- The Transit Gateway itself, all four TGW route tables, VPC attachments,
  associations, and propagations (native AWS resources - see
  `environments/single/main.tf`).
- The Shared Services CE site object and node (SMSv2, single-node,
  Marketplace AMI) - see `modules/f5xc-ce-site`.

Only the F5XC-side "External Connector" peering object and the
AWS-side third-party tunnel-termination attachment (if it turns out to be
a distinct resource from a standard VPC attachment) are stubbed here.

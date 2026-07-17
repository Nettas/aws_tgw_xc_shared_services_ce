# ADR 0001: Single-AZ (and single-node CE) for this iteration

## Status

Accepted for the current iteration. Revisit once the basic
VPC/TGW/CE/External-Connector path is proven end-to-end.

## Decision

All four VPCs use a single Availability Zone (`us-east-2a`), and the F5
CE is deployed as a single node (`enable_ha = false`), not a 3-node HA
cluster.

## Why, for now

- Fewer moving parts while validating the core design (CIDR plan, TGW
  routing, CE registration/tunnel-token automation, and eventually the
  External Connector peering) for the first time.
- Fewer subnets to reason about: 1 AZ means 1 subnet per VPC role (2 for
  Shared Services: SLO + SLI) instead of 3+ per role for HA.
- Faster/cheaper to iterate and tear down while the design is still being
  proven out.

## Ramifications of staying single-AZ (i.e., what we're accepting)

1. **The Availability Zone is a single point of failure for everything in
   it.** If `us-east-2a` has an outage, every VPC, every client node, and
   - critically - the CE itself all go down simultaneously, since they're
   all in the same AZ.
2. **The CE is a single point of failure for the whole hub function**,
   independent of AZ: because it's one EC2 instance, if it stops (patch
   reboot, instance failure, etc.), origin discovery and VIP publishing
   for *all three spokes* stops, since every spoke's only path to
   anything is through the Shared Services VPC.
3. **No redundancy in the Transit Gateway attachments.** Each attachment
   in this design has exactly one subnet (one AZ), so each attachment is
   backed by a single ENI in a single AZ. If that AZ has a control-plane
   issue affecting ENIs, the attachment itself could be affected, not
   just the instances behind it.

None of this matters for validating routing logic and CE automation, but
all of it matters before treating this as anything other than a lab/dev
environment.

## What changes if/when we go multi-AZ

This is the deeper question you asked about - here's what actually
changes, resource by resource, versus what people often assume changes
but doesn't.

### Transit Gateway attachments are regional, not AZ-bound - but each attachment's *availability* is only as good as the AZs you give it a subnet in

A single TGW VPC attachment can (and for production, should) include
**one subnet per AZ** you want that attachment to be resilient across
(`subnet_ids = [subnet_az_a, subnet_az_b, subnet_az_c]` on
`aws_ec2_transit_gateway_vpc_attachment`). AWS then provisions one
attachment ENI per AZ you list. This is a property of the *attachment*,
not of routing logic - the TGW route tables, associations, and
propagations in `tgw.tf` do not change at all when you add AZs to an
attachment. What changes is:

- You need additional subnets (one per AZ) in each VPC for both the
  workload subnet and (for Shared Services) both SLO and SLI.
- The `modules/vpc` module already supports this without changes - just
  add more entries to the `subnets` list with different
  `availability_zone` values, and add the new subnet(s) to each relevant
  `aws_ec2_transit_gateway_vpc_attachment`'s `subnet_ids` list.
- Each additional AZ subnet needs its own route table (the module already
  does this 1:1), and that route table needs the same routes (IGW
  default, TGW routes) as its sibling subnet in the other AZ(s) - this is
  a copy/paste-shaped change in `vpc.tf`, not a new pattern.

### Routing from an instance in one AZ of a VPC to an instance in another AZ of the *same* VPC

This is **not** a Transit Gateway concern at all - it's handled by the
VPC's own implicit router the same way single-AZ intra-VPC traffic is,
regardless of how many subnets/AZs exist. Every subnet's route table
already has an implicit `local` route for the VPC's CIDR block that AWS
manages for you (you'll never see this as a Terraform resource - it's
built in). So two instances in different AZs but the same VPC (e.g., if
Client A grew a second AZ) can already reach each other with zero TGW
involvement. The only things you pay for are:

- A small per-GB **cross-AZ data transfer charge** (this exists whether
  or not TGW is involved, any time traffic crosses an AZ boundary within
  a region).
- Negligible additional latency (sub-millisecond typically, since AZs in
  a region are metro-distance apart).

### Routing from an instance in one AZ to a *different VPC* attached via TGW, where the TGW attachment only has a subnet in a different AZ

This is the case that actually matters and is easy to get wrong. If
Client A had instances in `us-east-2a` and `us-east-2b`, but the Client A
TGW attachment's `subnet_ids` only included the `us-east-2a` subnet, then
**all** Client A traffic destined for the Shared Services VPC - including
from the `us-east-2b` instance - has to first reach the attachment's
single ENI in `us-east-2a` (via the VPC's own intra-VPC routing, same as
above), then cross into the TGW from there. This works, but:

- It adds an extra intra-VPC hop + associated cross-AZ charge for
  `us-east-2b` traffic specifically, on top of whatever cross-AZ hops
  happen on the Shared Services side.
- It makes `us-east-2a` a soft dependency for *all* of Client A's
  east-west traffic, even though Client A itself spans two AZs - which
  partially defeats the purpose of going multi-AZ in the first place.

**The fix, if/when we go multi-AZ, is straightforward: give every TGW
attachment a subnet in every AZ the VPC actually uses.** This repo's
module structure already supports that without redesigning anything - it's
purely "add more subnet entries and more attachment subnet_ids," not a
routing model change.

### The CE specifically: single-node vs. HA is an orthogonal decision to AZ count

Going multi-AZ on the *VPCs* does not, by itself, make the CE HA - a
single EC2 instance is always bound to one AZ no matter how many subnets
exist elsewhere. To get CE-level HA you need one of the two models F5
documents:

1. **3-node HA cluster (default HA model)**: requires 3 subnets per
   interface, one per AZ (so 3 SLO subnets + 3 SLI subnets = 6 subnets in
   the Shared Services VPC), with all 3 nodes provisioned together and
   registered before the site comes fully online. F5 also requires
   sequential token generation/node bring-up (generate token, deploy
   node, wait ~2-3 minutes, repeat) rather than generating all 3 tokens
   upfront - this repo's fully-automated single-node token flow in
   `modules/f5xc-ce-site` would need to become a 3-node,
   dependency-ordered version of the same pattern.
2. **Network-based HA (2+ independent single-node sites behind an AWS
   NLB)**: simpler to build in Terraform (just more copies of the
   single-node module, each in a different AZ), but per F5's guidance
   this model is really meant for publishing applications *on* the CE
   itself with an NLB as the single entry point - it's a different
   traffic-engineering pattern than the shared-services/hub role this CE
   plays here, so it's a worse fit for this specific design than the
   3-node cluster would be.

Either HA model also interacts with **AWS Transit Gateway Appliance
Mode**: when a stateful network appliance (which the CE is) sits behind a
TGW attachment across multiple AZs, enabling Appliance Mode on that
attachment pins a given traffic *flow* to a single AZ for its lifetime,
avoiding asymmetric-routing problems where the request goes through one
CE node/AZ and the response comes back through a different one. This
would need to be added to the Shared Services attachment
(`transit_gateway_default_route_table_association`/`appliance_mode_support`
argument on `aws_ec2_transit_gateway_vpc_attachment`) before any HA CE
model goes into production.

### Summary checklist for a future multi-AZ pass

- [ ] Add AZ-b (and c, for CE HA) subnet entries to each VPC's `subnets`
      list in `vpc.tf`.
- [ ] Add the new subnet IDs to each relevant
      `aws_ec2_transit_gateway_vpc_attachment.subnet_ids`.
- [ ] Add matching IGW-default and TGW routes to each new subnet's route
      table (copy the pattern already used for the AZ-a subnets).
- [ ] Decide single-node-per-AZ-behind-NLB vs. 3-node HA cluster for the
      CE, and update `modules/f5xc-ce-site` accordingly (this is the
      biggest single change - the current module assumes exactly one
      SLO + one SLI ENI/instance).
- [ ] Enable Appliance Mode on the Shared Services TGW attachment if
      going HA on the CE.
- [ ] Re-run the token-generation sequencing described in F5's SMSv2 HA
      docs if moving to the 3-node model - this is a process change, not
      just a Terraform change (nodes must be brought up serially with a
      wait, not all at once).

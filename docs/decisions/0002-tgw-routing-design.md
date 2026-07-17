# ADR 0002: Transit Gateway routing - hub-and-spoke with spoke isolation

## Status

Accepted.

## Decision

Four Transit Gateway route tables, one per VPC attachment, with:

- `default_route_table_association = "disable"` and
  `default_route_table_propagation = "disable"` set on the Transit
  Gateway itself, so nothing happens implicitly - every association and
  propagation below is an explicit Terraform resource.
- Each attachment **associated** with exactly one route table (governs
  routing decisions for traffic *from* that attachment).
- Each spoke attachment (Client A, Client B, On-Prem Mimic) **propagates**
  its own CIDR(s) only into the Shared Services route table.
- The Shared Services attachment **propagates** its CIDR into each of the
  three spoke route tables.

| TGW Route Table | Associated Attachment | Routes it contains (via propagation) |
|---|---|---|
| `rtb-client-a` | Client A | Shared Services CIDR (`10.0.0.128/26`) only |
| `rtb-client-b` | Client B | Shared Services CIDR (`10.0.0.128/26`) only |
| `rtb-shared-services` | Shared Services | Client A (`10.0.0.0/26`), Client B (`10.0.0.64/26`), On-Prem Mimic Class B (`172.16.0.0/24`) and Class C (`192.168.50.0/24`) |
| `rtb-onprem-mimic` | On-Prem Mimic | Shared Services CIDR (`10.0.0.128/26`) only |

## Why spoke isolation, not full mesh

The Shared Services VPC exists specifically to host the F5 CE in a
position where it discovers origins and publishes VIPs *to* the other
VPCs. If Client A could route directly to Client B (or to the On-Prem
Mimic VPC) without transiting the Shared Services VPC, the CE would be
optional rather than mandatory for east-west traffic - workloads could
route around it, bypassing whatever discovery/publishing/policy logic
lives there. Isolating the spokes from each other and only letting them
reach the hub is what makes "shared services" a real architectural
chokepoint rather than just a label.

If a future use case genuinely needs direct spoke-to-spoke connectivity
(bypassing the CE) for a specific pair of VPCs, the right move is a
**narrowly-scoped additional propagation** (e.g., propagate Client A's
CIDR into `rtb-client-b` and vice versa, only for that one pair), not a
switch to full-mesh for everything - and it should be called out
explicitly in an update to this ADR, since it changes the security/traffic
model in a way future readers need to know was deliberate.

## Regular VPC route tables vs. TGW route tables - two different layers

It's easy to conflate these, so to be explicit: the table above describes
the **Transit Gateway's own route tables**, which control what the TGW
does with traffic once it arrives at an attachment. Separately, **each
VPC's own subnet route tables** (created 1:1 per subnet by
`modules/vpc`) need a plain `aws_route` pointing `destination_cidr_block
-> transit_gateway_id` for anything that should actually be sent to the
TGW in the first place - see `vpc.tf`. Both layers have to agree, or
traffic will either never reach the TGW (missing VPC-level route) or
arrive at the TGW and get dropped/blackholed (missing TGW-level
propagation/route). The comments in `vpc.tf` and `tgw.tf` cross-reference
each other for this reason.

## Consequences

- Client A and Client B cannot ping each other, resolve each other's
  private DNS, or reach any service the other hosts directly - by design.
  Don't treat failed Client A -> Client B connectivity tests as a bug;
  it's the whole point.
- Any new spoke VPC added later should default to the same pattern (its
  own dedicated TGW route table, propagate only into
  `rtb-shared-services`, receive only the Shared Services CIDR back) unless
  there's a specific, documented reason to deviate.
- The Shared Services VPC's route table (specifically its SLI subnet's
  route table) is the one place in this design that needs to "see"
  everything - if a new spoke is added, its CIDR needs both a TGW
  propagation into `rtb-shared-services` *and* a plain `aws_route` in the
  Shared Services SLI subnet's route table pointing at the TGW (see the
  `shared_svcs_sli_to_*` resources in `vpc.tf` for the existing pattern to
  copy).

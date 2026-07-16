# Project Instructions

Operating playbook for anyone working in this repo - contributors,
reviewers, and future-you six months from now.

## Guiding principles

1. **Explicit over clever.** The Transit Gateway routing in this design is
   deliberately hand-written in `environments/single/tgw.tf` and
   `vpc.tf` rather than abstracted into a generic "TGW module that takes a
   map of VPCs" - the whole point of this repo is a specific, readable
   hub-and-spoke topology, and hiding that behind heavy abstraction makes
   it harder to audit.
2. **No orchestrated F5 site types.** We use F5 Distributed Cloud Secure
   Mesh Site v2 (SMSv2) with `not_managed {}` (the CE bring-up is fully
   under our own Terraform/AWS control) - never `volterra_aws_vpc_site` or
   `volterra_aws_tgw_site` (F5-orchestrated cloud resources). This is a
   firm project constraint, not just a preference.
3. **Never guess at unconfirmed resource schemas.** If a Terraform
   resource's existence or schema can't be confirmed against current
   provider docs, it gets stubbed with a clear `README.md` explaining
   what's missing (see `modules/f5xc-external-connector/`) rather than
   invented. A wrong resource that silently no-ops or partially applies is
   worse than an honest gap.
4. **Comment the "why," not just the "what."** Every `.tf` file should
   have a header block explaining its purpose, and any non-obvious
   resource (security group rules, route table associations,
   provider-specific quirks) should have an inline comment explaining the
   reasoning, not just restating the resource name.
5. **State is sacred.** Never run `terraform apply` against
   `environments/single` without first confirming you're pointed at the
   correct S3 backend/key. Never edit `.tfstate` by hand. Use `terraform
   state list` / `terraform state show` to inspect, not manual file edits.

## Making changes

1. Create a branch off `main` for any change (`git checkout -b
   feat/short-description`).
2. Run `terraform fmt -recursive` before committing - keep formatting
   consistent across the whole repo, not just the file you touched.
3. Run `terraform validate` in `environments/single` (and `bootstrap` if
   you touched it) before opening a PR.
4. Include the output of `terraform plan` in your PR description for any
   change that touches `environments/single` - reviewers should be able to
   see the blast radius without pulling the branch themselves.
5. Update the relevant `docs/decisions/*.md` file if your change reverses
   or meaningfully alters a prior decision (single-AZ vs multi-AZ, single
   vs HA CE, the TGW routing model) rather than just deleting the old
   rationale.

## Working with the F5 Distributed Cloud provider

- Pin the `volterraedge/volterra` provider version in
  `environments/single/versions.tf` and don't bump it without testing -
  F5XC provider resource schemas do change between minor versions.
- Never commit a `.p12` API credential file. Store it outside the repo
  and reference it via `f5xc_api_p12_file` in a gitignored
  `terraform.tfvars`.
- If you need to change anything about the CE's SLO interface after
  first `apply` (IP, MAC), you cannot modify it in place - you must
  destroy and recreate the site + instance. Budget for a maintenance
  window; this is an F5 platform constraint, not a Terraform limitation.
- Before touching `modules/f5xc-external-connector/`, read its `README.md`
  in full. Do not uncomment the sketch resource block in `main.tf` without
  first confirming the actual resource name/schema against
  `terraform providers schema -json` for your pinned provider version, or
  the current F5 API reference docs.

## Working with the Transit Gateway routing

Before changing anything in `tgw.tf`, re-read
`docs/decisions/0002-tgw-routing-design.md`. The current model is
deliberately restrictive (spokes can only reach the hub). If you need
spoke-to-spoke connectivity for a specific test, prefer adding a
**narrowly-scoped, well-commented** propagation/route rather than
switching the whole topology to full-mesh - and document why in the ADR.

## Environment promotion (future)

This repo currently supports a single environment
(`environments/single`). If/when we split into `dev`/`prod` or similar:

- Duplicate the `environments/single` directory structure rather than
  parameterizing environment name into a single directory with a
  workspace - keeping full separate `.tf` trees per environment makes
  blast radius and state isolation obvious at a glance.
- Each environment gets its own S3 state key and (optionally) its own
  bootstrap bucket/lock table, or a shared bucket with environment-scoped
  keys - decide and document this before creating the second environment.

## CI/CD (planned, not yet implemented)

`.github/workflows/` is intentionally empty right now. When we wire it
up, the plan is:

- `terraform fmt -check` + `terraform validate` on every PR.
- `terraform plan` posted as a PR comment on every PR touching
  `environments/**`.
- `terraform apply` gated behind manual approval on merge to `main`.
- Secrets (AWS credentials, F5XC API cert) via GitHub Actions OIDC / encrypted
  secrets - never plaintext in workflow YAML.

Do not add partial/half-working CI before this is deliberately scoped -
per current project sequencing we're validating the Terraform by hand
first.

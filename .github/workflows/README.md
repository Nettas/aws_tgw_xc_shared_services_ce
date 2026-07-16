# Reserved for CI/CD

No workflows yet, on purpose - see `PROJECT_INSTRUCTIONS.md` > "CI/CD
(planned, not yet implemented)". We're validating the Terraform by hand
first; workflow YAML will be added here once the manual `plan`/`apply`
path is proven out end-to-end (including the External Connector piece in
`modules/f5xc-external-connector/`).

Planned shape when this gets built:
- `pr-plan.yml`: `terraform fmt -check`, `terraform validate`,
  `terraform plan` (posted as a PR comment) on every PR touching
  `environments/**`.
- `apply.yml`: `terraform apply`, manually approved, triggered on merge to
  `main`.

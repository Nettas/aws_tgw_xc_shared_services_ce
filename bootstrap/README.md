# bootstrap/

One-time setup: creates the S3 bucket + DynamoDB lock table that
`environments/single` uses as its remote state backend.

This is a **separate root module with its own local state**, on purpose -
you cannot use an S3 backend that doesn't exist yet to store the state of
the Terraform run that creates that same S3 bucket (chicken-and-egg). Run
this once, by hand, before touching `environments/single`.

## Usage

```bash
cd bootstrap
terraform init
terraform apply -var="state_bucket_name=YOUR-GLOBALLY-UNIQUE-BUCKET-NAME"
```

Take note of the two outputs:

- `state_bucket_name`
- `lock_table_name`

Then update `environments/single/backend.tf`'s `bucket` (and
`dynamodb_table`, if you changed the default) to match, and run
`terraform init` inside `environments/single` to migrate/initialize that
environment against the new backend.

## What this creates

- An S3 bucket with versioning enabled (protects against accidental state
  corruption/loss), default SSE-S3 encryption, and all public access
  blocked.
- A DynamoDB table (`PAY_PER_REQUEST` billing, so no idle cost beyond the
  tiny amount of stored state) used for state locking, so two people (or
  a person and CI) can't `apply` concurrently and corrupt state.

## Should I ever re-run `terraform apply` here?

Rarely - only if you need to change something about the bucket/table
itself (e.g., add a lifecycle policy). Do not delete or recreate the
bucket/table once `environments/single` has state stored in it, or you
will lose that state.

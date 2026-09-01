# Two-layer Terrateam evaluation setup

Two independent Terraform states where the second consumes the first's outputs,
built entirely from dummy resources so it runs with no cloud credentials.

```
infra/network   produces  ->  vpc_id, subnet_ids, subnet_cidrs, environment
infra/app       consumes  <-  via terraform_remote_state, builds instances per subnet
```

`infra/app` declares `depends_on: 'dir:infra/network'` in
[.terrateam/config.yml](../.terrateam/config.yml), so a pull request touching
both directories gets **network planned and applied first**, and app only runs
once network has applied cleanly.

## How the two states are wired together

`infra/app` reads the upstream outputs with a standard `terraform_remote_state`
data source. You can see the values cross the boundary in the app layer's plan:

```
+ resource "null_resource" "instance" {
    + triggers = {
        + "subnet_id" = "subnet-36fd920f"   # produced by infra/network
        + "vpc_id"    = "vpc-ff71b01c"      # produced by infra/network
      }
  }
```

## The one compromise: committed state

Terrateam never stores Terraform state — it stays in whatever backend you
choose. With no cloud backend available yet, `infra/network/terraform.tfstate`
is **committed to git** so the app layer has something to read. `.gitignore`
negates the usual `*.tfstate` rule for that one path only; `infra/app`'s state
is still ignored.

This is fine for kicking the tires and wrong for production. Moving to a real
backend is a two-file change:

```hcl
# infra/network/main.tf
backend "s3" {
  bucket = "your-tf-state"
  key    = "network/terraform.tfstate"
  region = "eu-central-1"
}

# infra/app/main.tf
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "your-tf-state"
    key    = "network/terraform.tfstate"
    region = "eu-central-1"
  }
}
```

Nothing else — no resource, output, or Terrateam config — has to change.

Because applies in CI will not commit state back, the committed state is a
fixed snapshot. Plans against it are correct and repeatable, which is what you
want for evaluating Terrateam's behaviour. To refresh the snapshot, run
`terraform apply` in `infra/network` locally and commit the resulting state.

## Things to try

| What you want to see | Change to make |
| --- | --- |
| **Layered ordering** | Edit both `infra/network/main.tf` and `infra/app/main.tf` in one PR. Network plans and applies first; app follows. |
| **Independent dirspaces** | Change only `instances_per_subnet` in `infra/app/main.tf`. Only the app layer plans. |
| **Output propagation** | Change `subnet_count` in `infra/network/main.tf`. The new subnet count reaches app only after network is applied and its state is refreshed. |
| **Shared module fan-out** | Edit `modules/main.tf`. The `modules/**/*.tf` file pattern makes every consuming directory plan. |
| **Sensitive value handling** | `internal_endpoint` is marked `sensitive`. Check how it renders in the PR comment. |
| **Failing pre-hook** | Break the formatting in any `.tf` file. The `terraform fmt -check` pre-plan hook reports it without blocking (`ignore_errors: true`). |
| **Apply requirements** | Set `approved.enabled: true` in the config. Note GitHub will not let you approve your own PR, so this blocks applies in a solo fork. |
| **Drift detection** | Hand-edit a `hex` value inside `infra/network/terraform.tfstate` and push. The next scheduled drift run sees a diff and opens an issue via the `drift_create_issue` hook. |
| **Custom workflows** | Uncomment the `workflows` block in the config to add a `terraform validate` step (or tflint/checkov). |

## Running it locally

```bash
cd infra/network && terraform init && terraform apply
cd ../app && terraform init && terraform plan
```

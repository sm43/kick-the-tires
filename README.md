# Terrateam evaluation

Two independent Terraform states where the second consumes the first's outputs,
built entirely from dummy resources so everything runs with no cloud
credentials.

```
infra/network   produces  ->  vpc_id, subnet_ids, subnet_cidrs, environment
infra/app       consumes  <-  via terraform_remote_state, one instance per subnet
modules/        shared module used by infra/app
```

`infra/app` declares `depends_on: 'dir:infra/network'` in
[.terrateam/config.yml](.terrateam/config.yml), so a pull request touching both
directories gets **network planned and applied first**, and app only runs once
network has applied cleanly.

## How the two states are wired together

`infra/app` reads the upstream outputs with a standard `terraform_remote_state`
data source. You can watch the values cross the state boundary in the app
layer's plan:

```
# module.instance[0].null_resource.this will be created
+ triggers = {
    + "subnet_id" = "subnet-36fd920f"   # produced by infra/network
    + "vpc_id"    = "vpc-ff71b01c"      # produced by infra/network
  }
```

## Two things that will bite you

**Config is read from the base branch, not the PR branch.** Terrateam loads
`.terrateam/config.yml` from the pull request's *destination* branch. A config
change cannot be tested in the pull request that introduces it — it only takes
effect once merged. A config that fails to parse (for example a file where
every line is commented out, which YAML reads as `null`) blocks every operation
with `null is not of type "object"` and no plan runs at all.

**State is committed on purpose.** Terrateam never stores Terraform state — it
stays in whatever backend you choose. With no cloud backend yet,
`infra/network/terraform.tfstate` is committed so the app layer has something
to read; `.gitignore` negates the usual `*.tfstate` rule for that one path only,
and `infra/app`'s state is still ignored.

This is fine for kicking the tires and wrong for production. Moving to a real
backend is a two-block change:

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

No resource, output, or Terrateam config has to change.

Because applies in CI do not commit state back, the committed state is a fixed
snapshot: the app layer plans against the *last committed* network state, not
against whatever network is about to apply. Refresh it deliberately:

```bash
cd infra/network && terraform apply
git add -f terraform.tfstate && git commit -m "Refresh network state snapshot"
```

## Plan on main and drift detection

There is no plan-on-push-to-main in Terrateam; plans are pull-request scoped.
The way to keep main honest is **drift detection**, which runs a plan against
every matching dirspace on the default branch on a schedule and opens a GitHub
issue on any difference. It is enabled hourly on the `demo` tag:

```yaml
drift:
  enabled: true
  schedules:
    hourly:
      tag_query: 'demo'
      schedule: hourly
      reconcile: false
```

`reconcile: false` means report only. Setting it `true` makes Terrateam apply
the drift plan automatically with no review — leave it off until you trust what
drift reports.

Caveat worth knowing: these resources have no real remote, so a refresh never
finds genuine drift. To force a drift signal, hand-edit a `hex` value inside
`infra/network/terraform.tfstate` on main and wait for the next scheduled run.

## Things to try

| What you want to see | Change to make |
| --- | --- |
| **Layered ordering** | Edit both `infra/network/main.tf` and `infra/app/main.tf` in one PR. Network plans and applies first; app follows. |
| **Independent dirspaces** | Change only `instances_per_subnet` in `infra/app/main.tf`. Only the app layer plans. |
| **Output propagation** | Change `subnet_count` in `infra/network/main.tf`, apply, refresh the state snapshot. The new subnet count reaches app on the next run. |
| **Shared module fan-out** | Edit `modules/main.tf`. The `modules/**/*.tf` file pattern makes every consuming directory plan. |
| **Sensitive value handling** | `internal_endpoint` is marked `sensitive`. Check how it renders in the PR comment. |
| **Failing pre-hook** | Break the formatting in any `.tf` file. The `terraform fmt -check` pre-plan hook reports it without blocking (`ignore_errors: true`). |
| **Apply requirements** | Set `approved.enabled: true` in the config. Note GitHub will not let you approve your own PR, so this blocks applies in a solo fork. |
| **Custom workflows** | Uncomment the `workflows` block in the config to add a `terraform validate` step (or tflint/checkov). |

## Running it locally

```bash
cd infra/network && terraform init && terraform apply
cd ../app && terraform init && terraform plan
```

## Repository layout

| Path | Purpose |
| --- | --- |
| `infra/network/` | Producer layer: dummy network resources and outputs |
| `infra/app/` | Consumer layer: reads network outputs via `terraform_remote_state` |
| `modules/` | Shared module consumed by `infra/app` |
| `.terrateam/config.yml` | Terrateam configuration |
| `.github/workflows/terrateam.yml` | Terrateam GitHub Actions entrypoint (do not edit) |

## Reference

- [Terrateam docs](https://docs.terrateam.io/)
- [Layered runs](https://docs.terrateam.io/workflows/advanced/layered-runs/)
- [Drift detection](https://docs.terrateam.io/governance/drift-detection/)
- [Configuration reference](https://docs.terrateam.io/reference/configuration/)

## License

MIT. See [LICENSE](LICENSE).

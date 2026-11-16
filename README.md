# Give Your Agent a Cloud It Can Break

A two-hour hands-on workshop for the University of Houston, Sugar Land campus.
You run an AWS-shaped cloud on your laptop with [Floci](https://floci.io), build an S3 → SQS → Lambda pipeline with
Terraform, then let a coding agent break it and fix it as many times as it needs. No AWS account, no credit card.

## 👩‍🎓 Here for the workshop?

**Start with [`workshop/README.md`](workshop/README.md).** It has the setup checklist and every lab.

- Do the **Before you arrive** checklist at home: Docker, the `floci` CLI, AWS CLI v2, Terraform, and the image pulls.
- Stuck on a step? [`workshop/STEPS.md`](workshop/STEPS.md) shows each command with the output you should see.
- Fell behind? [`workshop/solutions/`](workshop/solutions/) has the catch-up notes and the Lab 3 fix.

---

## What's in this repo

```text
workshop/            The labs students follow
  README.md          Setup checklist and Labs 0–4
  STEPS.md           Verified run-through: every command, its real output and timing
  lab0-setup/        env.sh: fallback for students without the floci CLI
  lab1-cli/          A bucket and a queue with the AWS CLI
  lab2-terraform/    The working pipeline (main.tf, src/handler.py, verify.sh)
  lab3-agent/        The same pipeline with two seeded bugs, plus PROMPT.md for the agent
  lab4-reset/        accounts.sh: isolated accounts on one Floci
  solutions/         Catch-up notes and lab3.diff
slides/              The reveal.js deck (works offline). See slides/README.md
```

## Present the slides

```bash
cd slides
python3 -m http.server 8000      # open http://localhost:8000
```

VS Code Live Server works too. Press `S` for speaker view with notes, `F` for fullscreen, `R` to replay the agent log
on the "Twelve attempts" slide. After editing the CSS, hard-refresh (Cmd+Shift+R).
Details, branding and PDF export: [`slides/README.md`](slides/README.md).

The deck follows one story: **Alex**, a student whose agent runs all night against a real AWS account and leaves a bill.
Each lab is a chapter of Alex's week. The speaker notes carry the narration and where every number comes from.

## Rehearse the workshop

Follow [`workshop/STEPS.md`](workshop/STEPS.md) top to bottom; the outputs and timings there are what students should see.

To rehearse without touching your own `floci` container, use a throwaway instance on another port and point
Terraform at it with an environment variable, so no `.tf` file changes:

```bash
E=(--container floci-rehearsal --endpoint http://localhost:14566)   # zsh/bash array
floci aws start --container floci-rehearsal --port 14566 --endpoint http://localhost:14566
eval "$(floci aws env "${E[@]}")"
export TF_VAR_endpoint=http://localhost:14566
# ... run the labs from a copy of workshop/ ...
floci aws stop --remove "${E[@]}"
```

`floci aws start` on a stopped container deletes and recreates it, so use a new container name for rehearsals.

## When Floci releases a new version

The slides make version-specific claims (slide "What an emulator can't tell you" and "Time spent waiting").
Re-check them before presenting:

1. **Pull it:** `docker pull floci/floci:latest`, then check `floci aws version` on a running instance.
   Update the CLI with `brew upgrade floci` or `floci update`.
2. **Fidelity gaps.** On a throwaway instance, confirm these are still *accepted* by Floci (AWS rejects them):
   - an S3 → SQS notification when the queue policy doesn't let S3 send
   - a Lambda event source mapping with queue visibility timeout shorter than the function timeout
   - a Lambda function whose IAM role doesn't exist
   - re-creating an SQS queue with the same name right after deleting it (AWS makes you wait 60 s)

   And that these are still *rejected*: a notification to a queue that doesn't exist, and an EKS cluster with a subnet
   that doesn't exist.
3. **Timings.** Time EKS create and delete, RDS PostgreSQL create, `create-vpc`, the Lab 2 apply, and `floci aws reset`.
   Poll with `describe-*` every 0.5 s. **Don't use `aws eks wait cluster-active`**: it polls every 30 s and makes
   Floci look like 31 s.
4. **Run the labs** following `workshop/STEPS.md` and compare.
5. **Update** the version and numbers in `slides/index.html` (those two slides, the Monday-night slide, and their
   speaker notes), the wrap-up in `workshop/README.md`, and the header of `workshop/STEPS.md`.

Last verified: **Floci 2.5.0, floci CLI 0.4.0, 2026-11-16.**

## Known gaps

- The real-AWS time for the Lab 2 "wipe and rebuild" loop (~3 min) is an **estimate**, built from the Terraform AWS
  provider's own waits and AWS's 60 s SQS queue-name rule. To replace it, time one `terraform destroy` plus
  `terraform apply` of `workshop/lab2-terraform` in a real sandbox account.
- Snapshots (`floci aws snapshot`) are not supported by the server yet, so the labs use `floci aws reset` instead.

## Credits

- [Floci](https://floci.io), MIT licensed. Slides follow the floci.io design system; Sora and Space Mono fonts (SIL OFL).
- The University of Houston logo is a trademark of the University of Houston, used here for this campus event.
- Workshop and slides by Hector Ventura · [hectorvent.dev](https://hectorvent.dev)

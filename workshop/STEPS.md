# Workshop run-through, step by step

Every lab from [`README.md`](README.md), run end to end the way a student would, with the real output and timings.
Use it to rehearse, to check a student's screen against what they should see, or to catch up after falling behind.

**Verified on 2026-11-16** on a MacBook (Apple Silicon), Docker 29.9.3:

| Tool | Version |
|---|---|
| Floci (server) | 2.5.0 |
| floci CLI | 0.4.0 |
| AWS CLI | 2.33.24 |
| Terraform | 1.5.6 (providers: hashicorp/aws 5.100.0, hashicorp/archive 2.8.1) |

Container images were already pulled. Timings below are from that run; yours will be close.

> The test run used a separate Floci container on port 14566 so it would not touch an existing `floci` container.
> The commands below are the student commands, on the default port 4566. Nothing else differs.

---

## Before you start (at home)

```bash
floci aws doctor
```

Before Floci is running, `doctor` reports that the container is missing and the endpoint is unreachable. That is expected.
It may also warn that `~/.aws/config` has no `s3.addressing_style = path`. **You can ignore that warning for this workshop:**
every S3 step below worked without it, on both `localhost.floci.io` and the offline `--host localhost` endpoint.

Pull the images and the Terraform providers once, at home:

```bash
docker pull floci/floci:latest
docker pull public.ecr.aws/lambda/python:3.12
cd workshop/lab2-terraform && terraform init
```

---

## Lab 0: Setup (≈ 2 min)

### Step 0.1: Start Floci

```bash
floci aws start
```

```text
Container started (23e57b4129e6)
Waiting for Floci AWS to be ready...
Floci AWS is ready (http://localhost:4566)
```

Took **0.5 s** with the image already pulled. `start` waits until Floci is ready and mounts the Docker socket for you (Lambda needs it).

### Step 0.2: Check it

```bash
floci aws status
```

```text
Floci AWS Status

  Container:  floci  running
  Image:      floci/floci:latest
  Ports:      4566->4566/tcp
  Endpoint:   http://localhost:4566
  Reachable:  yes
  Version:    2.5.0
  Edition:    floci-always-free
```

### Step 0.3: Point the AWS CLI at Floci

```bash
eval "$(floci aws env)"
```

It exports:

```bash
export AWS_ENDPOINT_URL='http://localhost.floci.io:4566'
export AWS_ACCESS_KEY_ID='test'
export AWS_SECRET_ACCESS_KEY='test'
export AWS_DEFAULT_REGION='us-east-1'
```

Run it again in every new terminal.

| Situation | Use instead | Verified |
|---|---|---|
| No internet (`localhost.floci.io` needs DNS) | `eval "$(floci aws env --host localhost)"` | ✅ S3 and SQS work, no extra config |
| No `floci` CLI | `docker run …` from the README, then `source lab0-setup/env.sh` | ✅ |

### ✅ Checkpoint 0

```bash
aws sts get-caller-identity
```

```json
{
    "UserId": "000000000000",
    "Account": "000000000000",
    "Arn": "arn:aws:iam::000000000000:root"
}
```

---

## Lab 1: Your first cloud resources (≈ 3 min)

### Step 1.1: A bucket and a file

```bash
cd lab1-cli
aws s3 mb s3://uploads
aws s3 cp hello.txt s3://uploads/
aws s3 ls s3://uploads/
```

```text
make_bucket: uploads
upload: ./hello.txt to s3://uploads/hello.txt
2026-11-16 15:24:01         14 hello.txt
```

### Step 1.2: A queue

```bash
aws sqs create-queue --queue-name uploads-events
aws sqs list-queues
```

```json
{
    "QueueUrl": "http://localhost:4566/000000000000/uploads-events"
}
{
    "QueueUrls": [
        "http://localhost:4566/000000000000/uploads-events"
    ]
}
```

### ✅ Checkpoint 1

`aws s3 ls s3://uploads/` lists `hello.txt` (14 bytes).

### Fast finishers

```bash
QUEUE=$(aws sqs get-queue-url --queue-name uploads-events --query QueueUrl --output text)
aws sqs send-message --queue-url "$QUEUE" --message-body "hello from the CLI"
aws sqs receive-message --queue-url "$QUEUE"
```

The message comes back with `"Body": "hello from the CLI"`.

### Step 1.3: Reset before Lab 2

```bash
floci aws reset -y
```

```text
+ Floci AWS state reset  (http://localhost:4566)
```

Took **0.4 s**. `aws s3 ls` and `aws sqs list-queues` are now empty.

**Forgot the reset?** Lab 2's apply fails, as it would on real AWS:

```text
Error: creating S3 Bucket (uploads): BucketAlreadyExists
Error: creating SQS Queue (uploads-events): ... QueueAlreadyExists: A queue already exists with the same name but different attributes.
```

Terraform has already created the IAM role and the Lambda by then. Fix: `floci aws reset -y`, `rm -f terraform.tfstate*`, apply again.

---

## Lab 2: Infrastructure as code (≈ 3 min of commands, plus reading `main.tf`)

### Step 2.1: Apply

```bash
cd ../lab2-terraform
terraform init
time terraform apply -auto-approve
```

What you will see, in order (trimmed):

```text
aws_iam_role.lambda: Creation complete after 0s [id=process-upload-role]
aws_s3_bucket.uploads: Creation complete after 0s [id=uploads]
aws_lambda_function.process_upload: Creation complete after 5s [id=process-upload]
aws_sqs_queue.events: Still creating... [10s elapsed]
aws_sqs_queue.events: Still creating... [20s elapsed]
aws_sqs_queue.events: Creation complete after 25s
aws_iam_role_policy.lambda: Creation complete after 0s
aws_lambda_event_source_mapping.from_queue: Creation complete after 1s
aws_sqs_queue_policy.allow_s3: Still creating... [10s elapsed]
aws_sqs_queue_policy.allow_s3: Still creating... [20s elapsed]
aws_sqs_queue_policy.allow_s3: Creation complete after 26s
aws_s3_bucket_notification.to_queue: Creation complete after 0s [id=uploads]

Apply complete! Resources: 8 added, 0 changed, 0 destroyed.

Outputs:
bucket = "uploads"
function = "process-upload"
queue_url = "http://localhost:4566/000000000000/uploads-events"
```

Took **57.6 s**. The two "Still creating…" waits (25 s each) are the Terraform AWS provider double-checking the
SQS queue and its policy, 6 reads 5 s apart. It does the same against real AWS. The CLI in Lab 1 made the same queue instantly.

### ✅ Checkpoint 2

```bash
./verify.sh
```

```text
Uploaded s3://uploads/verify-1794864347.txt, waiting for the Lambda...
2026-11-16T21:25:49.509000+00:00 2026/11/16/[$LATEST]fd2e43b5 PROCESSED s3://uploads/verify-1794864347.txt (54 bytes)
✅ Pipeline works
```

Passed on the first try, in about 2 s.

### By hand

```bash
aws s3 cp ../lab1-cli/hello.txt s3://uploads/
aws logs tail /aws/lambda/process-upload --follow
```

```text
... PROCESSED s3://uploads/hello.txt (14 bytes)
```

---

## Lab 3: Let the agent break it (≈ 5 min of commands with an agent; longer by hand)

### Step 3.1: Free the names

```bash
cd ../lab2-terraform && terraform destroy -auto-approve
cd ../lab3-agent
```

`Destroy complete! Resources: 8 destroyed.` in **36 s** (Terraform waits for the deleted queue and policy to disappear).

### Step 3.2: Give the agent `PROMPT.md`

Open the agent in `lab3-agent/`, with `eval "$(floci aws env)"` done in its terminal, and paste the prompt.
What follows is the loop the agent should go through. The same steps work by hand.

#### Attempt 1: apply fails on the first bug

```bash
terraform init
terraform apply -auto-approve
```

```text
Error: creating S3 Bucket (uploads) Notification: operation error S3: PutBucketNotificationConfiguration,
https response error StatusCode: 400, ... api error InvalidArgument: Unable to validate the following destination configurations

  with aws_s3_bucket_notification.to_queue,
  on main.tf line 66, in resource "aws_s3_bucket_notification" "to_queue":
```

Fails after **62 s** (the SQS waits happen first). The notification points at a queue that doesn't exist.

**Fix 1** in `main.tf`: the hard-coded ARN has a typo (`upload-events`). Use the reference instead:

```hcl
queue_arn = aws_sqs_queue.events.arn
```

#### Attempt 2: apply passes, verify fails

```bash
terraform apply -auto-approve      # Apply complete! Resources: 1 added ... (7 s)
./verify.sh
```

```text
❌ The Lambda did not process s3://uploads/verify-1794864485.txt within 60 seconds.
Recent Lambda logs:
... [ERROR] KeyError: 'Body'Traceback (most recent call last):  File "/var/task/handler.py", line 6, in handler    body = json.loads(record["Body"])
```

The error is only in the Lambda logs, not in Terraform. This is the teaching moment: the agent has to go read them.

> **Watch out:** the "Recent Lambda logs" also show `PROCESSED` lines from Lab 2. The log group outlives `terraform destroy`.
> They are old; look at the `KeyError` lines.

**Fix 2** in `src/handler.py`, line 6: SQS records use a lowercase key.

```python
body = json.loads(record["body"])
```

#### Attempt 3: everything passes

```bash
terraform apply -auto-approve      # Modifications complete ... 0 added, 1 changed (14 s)
./verify.sh
```

```text
... PROCESSED s3://uploads/verify-1794864588.txt (54 bytes)
✅ Pipeline works
```

The upload that failed in attempt 2 is retried by SQS (every 30 s) and processed too, about 20 s after the fix.

These two fixes are exactly [`solutions/lab3.diff`](solutions/lab3.diff), which applies cleanly:
`cd lab3-agent && patch -p1 < ../solutions/lab3.diff`.

### ✅ Checkpoint 3

`./verify.sh` prints `✅ Pipeline works`. Three applies in total; about 1.5 min of commands, all of it on attempt 1.

### Step 3.3: Break it again

Ask the agent: *"Destroy everything with terraform destroy and rebuild it from scratch, then verify."*

| Step | Time |
|---|---|
| `terraform destroy` | 36.5 s |
| `terraform apply` | 57.4 s |
| `./verify.sh` | ✅ |

About **1.5 min per loop** on Floci.

---

## Lab 4: Reset and run in parallel (≈ 3 min)

### Part A: Reset

```bash
floci aws reset -y
aws s3 ls
```

`+ Floci AWS state reset` in **1.5 s** (0.4 s when nothing is deployed; it also removes the Lambda containers).
`aws s3 ls` prints nothing. No internal `awslambda-…` bucket showed up on 2.5.0.

Rebuild:

```bash
rm -f terraform.tfstate*
time terraform apply -auto-approve      # 8 added, 57.4 s
./verify.sh                             # ✅ Pipeline works
```

**Skipping `rm -f terraform.tfstate*` still works**, but the apply took **97 s** instead of 57 s, because Terraform
first checks every resource in the old state and finds them gone. Keep the `rm`.

Reset + apply is about **1 min per loop**, against 1.5 min for destroy + apply.

### Part B: Isolated accounts

```bash
cd ../lab4-reset
./accounts.sh
```

```text
=== Account 111111111111
111111111111
make_bucket: same-name
=== Account 222222222222
222222222222
make_bucket: same-name
=== s3://same-name/owner.txt as seen by 111111111111
agent 111111111111 was here
=== s3://same-name/owner.txt as seen by 222222222222
agent 222222222222 was here
```

### ✅ Checkpoint 4

Each 12-digit access key lists only its own `same-name` bucket, and `aws sts get-caller-identity` returns that number as
the account. The default `test` key (account `000000000000`) sees neither bucket.

---

## Done for the day

```bash
floci aws stop --remove
```

```text
Stopping Floci AWS container 'floci'...
Stopped.
Container removed.
```

The Lambda and helper containers Floci started are removed with it.

---

## Summary

| Lab | Result | Commands take |
|---|---|---|
| 0 Setup | ✅ | ~1 s (`floci aws start` 0.5 s) |
| 1 CLI | ✅ | seconds; reset 0.4 s |
| 2 Terraform | ✅ first try | apply 57.6 s, verify ~2 s |
| 3 Agent | ✅ after 2 fixes, 3 applies | ~1.5 min; rebuild loop ~1.5 min |
| 4 Reset + accounts | ✅ | reset 1.5 s, rebuild 57 s |

Things that surprised us during the run, already reflected above:

- `floci aws doctor` warns about `s3.addressing_style`; not needed for any lab.
- Lab 3's verify output mixes in old Lab 2 log lines.
- Reset is about a second once a Lambda is deployed, not "instant".
- Forgetting `rm -f terraform.tfstate*` after a reset costs ~40 s but doesn't break anything.

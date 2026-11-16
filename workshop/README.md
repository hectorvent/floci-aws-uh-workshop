# Give Your Agent a Cloud It Can Break

Hands-on workshop, University of Houston (Sugar Land). Speaker: Hector Ventura, creator of [Floci](https://floci.io).

Today you run an AWS-shaped cloud on your laptop, build a small event pipeline with Terraform, then let a coding agent break it and fix it as many times as it needs. Nothing you do today touches a real AWS account or costs money.

| Time | Block | You do |
|---|---|---|
| 0-15 | Intro talk | Listen |
| 15-25 | [Lab 0: Setup](#lab-0-setup) | Start Floci, set fake credentials |
| 25-35 | [Lab 1: First resources](#lab-1-your-first-cloud-resources) | Bucket and queue with the AWS CLI |
| 35-50 | [Lab 2: Infrastructure as code](#lab-2-infrastructure-as-code) | S3 + SQS + Lambda with Terraform |
| 50-70 | [Lab 3: Let the agent break it](#lab-3-let-the-agent-break-it) | Agent fixes a broken pipeline |
| 70-80 | [Lab 4: Reset and run in parallel](#lab-4-reset-and-run-in-parallel) | Wipe, rebuild, isolate |
| 80-90 | Wrap-up | Limits, benefits, how to contribute |
| 90-120 | Q&A | Ask, keep hacking |

Stuck? Every lab has a **checkpoint** command. If yours doesn't match, raise your hand, or jump ahead with the code in [`solutions/`](solutions/). [`STEPS.md`](STEPS.md) shows every step with the output you should see.

---

## Before you arrive

Room Wi-Fi will be shared by everyone, so please do this at home:

- [ ] Docker Desktop (or Docker Engine) installed and **running**
- [ ] The [`floci` CLI](https://github.com/floci-io/floci-cli#installation), which starts and manages the emulator:
  ```bash
  brew install floci-io/floci/floci              # macOS / Linux with Homebrew
  curl -fsSL https://floci.io/install.sh | sh    # macOS / Linux without Homebrew
  iwr https://floci.io/install.ps1 | iex         # Windows (PowerShell)
  ```
  Then run `floci aws doctor`: it checks Docker and tells you what to fix.
- [ ] [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [ ] [Terraform](https://developer.hashicorp.com/terraform/install) 1.5 or newer
- [ ] Git, and this repo cloned
- [ ] Pull the images (about 1 GB in total):
  ```bash
  docker pull floci/floci:latest
  docker pull public.ecr.aws/lambda/python:3.12
  ```
- [ ] Download the Terraform providers: `cd workshop/lab2-terraform && terraform init`
- [ ] Optional but recommended: a coding agent you can already use (any CLI or IDE agent)

**Windows:** run the labs in WSL 2 or Git Bash. The scripts are bash.

You do **not** need an AWS account or a credit card.

---

## Lab 0: Setup

Start Floci with the `floci` CLI. It pulls the image if needed, starts the container (with the Docker socket mounted, so Floci can run your Lambda functions) and waits until it is ready:

```bash
floci aws start
floci aws status      # running, healthy, and which version
```

Point the AWS CLI at it with **fake** credentials:

```bash
eval "$(floci aws env)"
```

That sets:

```bash
export AWS_ENDPOINT_URL='http://localhost.floci.io:4566'
export AWS_ACCESS_KEY_ID='test'
export AWS_SECRET_ACCESS_KEY='test'
export AWS_DEFAULT_REGION='us-east-1'
```

These credentials are fake. They cannot reach a real AWS account. If they leak, nothing happens.

Open a new terminal later? Run `eval "$(floci aws env)"` again in it.

- **No internet in the room?** `localhost.floci.io` is looked up through public DNS. Use `eval "$(floci aws env --host localhost)"` instead.
- **Windows PowerShell:** `floci aws env --shell powershell | Invoke-Expression`, or use WSL 2.
- **Something wrong?** `floci aws doctor` checks your setup, and `floci aws logs --tail 50` shows what the emulator is doing.
- **No `floci` CLI at all?** Start the container by hand and use the fallback script:
  ```bash
  docker run -d --name floci -p 4566:4566 -v /var/run/docker.sock:/var/run/docker.sock floci/floci:latest
  source lab0-setup/env.sh
  ```

### ✅ Checkpoint

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

## Lab 1: Your first cloud resources

```bash
cd lab1-cli

aws s3 mb s3://uploads
aws s3 cp hello.txt s3://uploads/
aws s3 ls s3://uploads/

aws sqs create-queue --queue-name uploads-events
aws sqs list-queues
```

### ✅ Checkpoint

```bash
aws s3 ls s3://uploads/
```

shows `hello.txt`.

**Fast finisher:** send a message and read it back.

```bash
QUEUE=$(aws sqs get-queue-url --queue-name uploads-events --query QueueUrl --output text)
aws sqs send-message --queue-url "$QUEUE" --message-body "hello from the CLI"
aws sqs receive-message --queue-url "$QUEUE"
```

### Clean up before Lab 2

Lab 2 creates a bucket and a queue with the **same names**. Terraform will refuse to create something that already exists, just like real AWS would. Wipe the emulator:

```bash
floci aws reset -y    # deletes every resource, keeps Floci running
```

---

## Lab 2: Infrastructure as code

```text
  you ──► S3 bucket "uploads" ──event──► SQS queue "uploads-events" ──trigger──► Lambda "process-upload"
                                                                                        │
                                                                                        ▼
                                                                         CloudWatch Logs: PROCESSED ...
```

| Service | Its job here |
|---|---|
| S3 | Stores the files |
| SQS | Carries a message for every new file |
| Lambda | Runs `src/handler.py` for every message |
| IAM | Decides what the Lambda is allowed to do |
| Terraform | Describes all of it as code |

```bash
cd lab2-terraform
terraform init
time terraform apply -auto-approve
```

Open `main.tf` and find the `provider "aws"` block. The `endpoints` section is the only thing that makes this Terraform talk to Floci instead of AWS.

### ✅ Checkpoint

```bash
./verify.sh
```

```text
Uploaded s3://uploads/verify-1730000000.txt, waiting for the Lambda...
2026-... PROCESSED s3://uploads/verify-1730000000.txt (54 bytes)
✅ Pipeline works
```

Or by hand:

```bash
aws s3 cp ../lab1-cli/hello.txt s3://uploads/
aws logs tail /aws/lambda/process-upload --follow
```

The first upload can take a few seconds while the Lambda container starts.

---

## Lab 3: Let the agent break it

`lab3-agent/` is the same pipeline, **with bugs in it**. Don't read the solution. Let your agent find them.

```bash
cd ../lab2-terraform && terraform destroy -auto-approve   # free the names
cd ../lab3-agent
```

Open your coding agent **in the `lab3-agent/` folder** and give it the prompt in [`lab3-agent/PROMPT.md`](lab3-agent/PROMPT.md).

Watch for these four steps:

1. The agent applies and something fails
2. The agent reads the **real** error message
3. The agent edits the code and applies again
4. The agent verifies its own work (`./verify.sh`)

Count the attempts. Write the number down.

### ✅ Checkpoint

```bash
./verify.sh
```

prints `✅ Pipeline works`.

### Then break it again

Tell the agent: *"Destroy everything with terraform destroy and rebuild it from scratch, then verify."* How many attempts across the room? How much would that have cost on a real account?

**No agent?** Fix it yourself, as the agent would: run `terraform apply`, read the error, fix it, and repeat. When apply passes, run `./verify.sh` and read the Lambda logs: `aws logs tail /aws/lambda/process-upload`. Pair with a neighbor, or watch the projector.

---

## Lab 4: Reset and run in parallel

### Part A: Reset

```bash
floci aws reset -y
aws s3 ls
```

Everything is gone in about a second, and Floci never stopped.

Rebuild and time it:

```bash
cd lab3-agent
rm -f terraform.tfstate*        # the old state describes resources that no longer exist
time terraform apply -auto-approve
./verify.sh
```

### Part B: Isolated accounts

Floci uses your access key as the account ID when it is a 12-digit number. Two agents, two CI jobs, or two neighbors can share one Floci and never see each other's resources.

```bash
cd lab4-reset
./accounts.sh
```

Or by hand, in two terminals:

```bash
# Terminal A
export AWS_ACCESS_KEY_ID=111111111111
aws s3 mb s3://same-name
aws s3 ls

# Terminal B
export AWS_ACCESS_KEY_ID=222222222222
aws s3 mb s3://same-name      # no collision
aws s3 ls
```

### ✅ Checkpoint

Each account lists only its own `same-name` bucket, and `aws sts get-caller-identity` shows a different account in each terminal.

---

## Wrap-up: what an emulator can't tell you

Passing locally is not the same as passing on AWS. Floci returns real errors for many mistakes, and these are the gaps we found while building this workshop (re-checked on Floci 2.5.0). Each of these is **accepted by Floci but rejected by AWS**:

- An S3 → SQS notification when the queue policy doesn't allow S3 to send
- A Lambda event source mapping where the queue's visibility timeout is shorter than the function timeout
- A Lambda function whose IAM role doesn't exist

Also not emulated faithfully: IAM policy evaluation edge cases, service quotas, real latency and throttling, eventual consistency, and newer service features.

**Rule of thumb:** iterate locally, then validate once in a real sandbox account before production.

## Keep going

- Floci: <https://floci.io> (MIT licensed, free forever)
- Contact: <https://hectorvent.dev>

## Done for the day

```bash
floci aws stop --remove
```

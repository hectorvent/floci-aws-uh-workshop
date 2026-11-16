# Prompt for your coding agent

Copy everything in the box below into your agent, opened in this `lab3-agent/` folder.

```text
This folder has Terraform for a small AWS pipeline: an S3 bucket "uploads" sends an
event to the SQS queue "uploads-events" for every new file, and the Lambda
"process-upload" (src/handler.py) reads the queue and logs "PROCESSED s3://<bucket>/<key>".

Deploy it against the local AWS emulator at http://localhost:4566 with
`terraform init` and `terraform apply -auto-approve`, then run ./verify.sh to prove
the pipeline works end to end.

If anything fails, read the error message (Terraform output, or the Lambda logs with
`aws logs tail /aws/lambda/process-upload --since 10m`), fix the code, and try again
until ./verify.sh prints "Pipeline works".

Rules:
- Only use the local emulator (http://localhost:4566, or http://localhost.floci.io:4566 as
  set in AWS_ENDPOINT_URL) and the fake credentials test/test.
  Never use, read, or ask for real AWS credentials or profiles.
- Fix the root cause in main.tf or src/handler.py. Do not edit verify.sh.
- When you are done, tell me how many apply attempts it took and what you fixed.
```

Before you start, make sure the environment is set in the terminal the agent uses:

```bash
eval "$(floci aws env)"     # no floci CLI? source ../lab0-setup/env.sh
```

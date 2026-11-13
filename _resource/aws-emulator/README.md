# Test AWS Locally with AWS Emulator

Example code for the article
[AWS Emulator: Test AWS Code Locally Without an AWS Account](https://devopsvn.tech/aws-emulator-test-aws-locally/).

Tested with AWS Emulator 1.0.338, AWS CLI 2.37.7, Python 3.14, and boto3 1.44.2, on macOS
(Docker) and on Ubuntu 24.04 (native package).

| Path | Purpose |
| --- | --- |
| `Dockerfile` | Builds the emulator image. AWS does not publish a prebuilt image. |
| `scripts/start-emulator.sh` | Runs the emulator in Docker on `127.0.0.1:9297`. |
| `scripts/emulator-env.sh` | Points the AWS CLI and SDKs in your shell at the emulator. Source it. |
| `scripts/wait-for-emulator.sh` | Waits for the health check. Used by CI. |
| `cli/learn-aws-cli.sh` | AWS CLI practice: STS, S3, DynamoDB, and SQS. |
| `app/orders.py` | A small order service that writes to DynamoDB, S3, and SQS. |
| `app/tests/` | pytest integration tests that run against the emulator. |
| `ci/github-actions.yml` | GitHub Actions workflow that runs the tests with no AWS account. |

## 1. Start the emulator

On macOS or Windows, use Docker:

```sh
# Intel/AMD machine
docker build -t aws-emulator .
# Apple silicon or another Arm machine
docker build --build-arg EMULATOR_ARCH=aarch64 -t aws-emulator .

./scripts/start-emulator.sh       # keep this terminal open; Ctrl+C stops it
```

On Linux, you can install the package instead and run `aws-emulator`. See the
[Linux guide](https://docs.aws.amazon.com/emulator/latest/userguide/getting-started-linux.html).

## 2. Learn the AWS CLI

In a second terminal:

```sh
./cli/learn-aws-cli.sh
```

The script refuses to run unless `aws sts get-caller-identity` returns the emulator account
`000000000000`. Restart the emulator before you run it again, because it creates fixed names.

## 3. Test your software locally

```sh
source scripts/emulator-env.sh
python3 -m venv .venv && . .venv/bin/activate
pip install -r app/requirements.txt
pytest app/tests -v
```

`app/tests/conftest.py` stops the run if `AWS_ENDPOINT_URL` is not a local address or if the
account is not `000000000000`, so the tests never reach a real AWS account.

## 4. Run the tests in CI

Copy `ci/github-actions.yml` to `.github/workflows/` in your repository and change
`working-directory` to `.`. The job installs a pinned emulator version, starts it, and runs
pytest. It needs no AWS secrets.

`versions.json` lists versions as `1.0.338.1`. The package file name uses `1.0.338-1`, so set
`EMULATOR_VERSION` to `1.0.338`.

## Clean up

Press Ctrl+C in the emulator terminal. All emulated resources are deleted. Then:

```sh
docker image rm aws-emulator
```

# Terraform Project: AWS Logging Pipeline to Splunk

## Overview
This Terraform project deploys an AWS logging pipeline that captures CloudWatch logs and sends them to a Splunk endpoint. The pipeline consists of CloudWatch Logs, Kinesis, Lambda, and Firehose, ensuring efficient and automated log forwarding to Splunk.

## Notes
This module is IaC is split into three roots:
- Logging Account (Kinesis and Firehose to Splunk with S3 backup bucket)
- Source Accounts (Used as Terraform initial deployment for testing, this fails after timeout if CW Logs have more than two subscriptions)
- Source Accounts Lambda (Custom written lambda that will execute hourly to review the log groups and associate the subscription filter, this will note if the CW Logs group was updated, skipped or has errors) review the README in the SourceAccountsLambda folder for further details.

## Architecture
1. **CloudWatch Logs to Kinesis**
   - CloudWatch log groups are configured to stream logs to an Amazon Kinesis stream.

2. **Kinesis to Lambda**
   - A Lambda function processes logs from Kinesis and batches them for efficient delivery.
   - Logs are forwarded to Firehose on an hourly basis by default.

3. **Firehose to Splunk**
   - Firehose acts as the final transport layer, sending logs to a configured Splunk HTTP Event Collector (HEC) endpoint.
   
## AWS Resources Deployed
- **Amazon CloudWatch Logs**
  - Log groups configured to stream logs to Kinesis.
  
- **Amazon Kinesis Stream**
  - Handles log ingestion before passing them to the Lambda function.
  
- **AWS Lambda Function**
  - Processes and transforms logs before sending them to Firehose.
  - Configured with an execution role that allows it to read from Kinesis and write to Firehose.
  
- **Amazon Kinesis Firehose**
  - Configured to deliver logs to Splunk.
  - Uses IAM permissions to securely write data to the endpoint.
  
- **IAM Roles and Policies**
  - Permissions for CloudWatch Logs, Kinesis, Lambda, and Firehose interactions.
  
## Prerequisites
- Terraform >= 1.x
- AWS CLI configured with appropriate credentials
- Splunk HTTP Event Collector (HEC) endpoint

## Usage
1. Clone this repository:
   ```sh
   git clone <repo-url>
   cd <project-directory>/terraform/LoggingAccount
   ```
2. Initialize Terraform:
   ```sh
   terraform init
   ```
3. Preview the execution plan:
   ```sh
   terraform plan
   ```
4. Apply the configuration:
   ```sh
   terraform apply -auto-approve
   Copy the Terraform Output for the Destination ARN
   ```
5. Setup Spoke Accounts:
   ```sh
   git clone <repo-url>
   cd <project-directory>/terraform/SourceAccountsLambda
   ```
6. Initialize Terraform:
   ```sh
   terraform init
   ```
7. Preview the execution plan:
   ```sh
   terraform plan
   ```
8. Apply the configuration in each account, I'm using a pipeline:
   ```sh
   terraform apply -auto-approve
   ```

## Configuration
Modify the `variables.tf` file to customize:
- Kinesis stream settings
- Lambda function parameters
- Firehose delivery stream settings
- Splunk HEC endpoint

## Outputs
After deployment, Terraform provides output variables such as:
- Kinesis Delivery Stream Arn

## Security Considerations
- Ensure IAM policies are scoped to least privilege.
- Use AWS Secrets Manager or Parameter Store to manage sensitive credentials.
- Enable encryption for Kinesis and Firehose.

## Troubleshooting
- Check AWS CloudWatch Logs for errors in Lambda execution.
- Verify Kinesis and Firehose metrics in AWS Console.
- Ensure the Splunk HEC endpoint is reachable and has the correct token configured.

## License
This project is licensed under the MIT License.


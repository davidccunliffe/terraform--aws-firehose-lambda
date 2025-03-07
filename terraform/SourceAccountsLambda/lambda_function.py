"""
AWS Lambda Function: CloudWatch Log Group Subscription Filter Manager

Description:
This AWS Lambda function ensures that all CloudWatch log groups have a required subscription filter applied.
It performs the following actions:

  - Lists all CloudWatch log groups in the region.
  - Retrieves existing subscription filters for each log group.
  - If the log group has:
    - 0 or 1 filters, it applies the specified subscription filter.
    - 2 filters, and neither is the target, it logs a conflict.
  - Logs compliance status, skipped reasons, and errors to a designated CloudWatch log group.
  - Provides execution status (Success/Failure) and a clickable CloudWatch log group link.

Environment Variables:
  - LOG_GROUP_NAME: CloudWatch Log Group used for logging compliance and conflicts.
  - TARGET_SUBSCRIPTION_FILTER: The name of the subscription filter to be applied.
  - DESTINATION_ARN: The ARN of the subscription filter's destination (Lambda, Firehose, etc.).
  - AWS_REGION: The AWS region where the Lambda is executed.

Outputs:
  - Logs results into CloudWatch streams: compliance_status/YYYY-MM-DD, errors/YYYY-MM-DD.
  - Provides a clickable CloudWatch log group link in the response.

Author: David Cunliffe
Date:   2021-08-25

License:
MIT License

Copyright (c) 2025 David Cunliffe

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
"""

import boto3
import os
import json
import datetime

# zip lambda.zip lambda_function.py

# Environment Variables
LOG_GROUP_NAME = os.getenv("LOG_GROUP_NAME")
TARGET_SUBSCRIPTION_FILTER = os.getenv("TARGET_SUBSCRIPTION_FILTER")
DESTINATION_ARN = os.getenv("DESTINATION_ARN")
AWS_REGION = os.getenv("AWS_REGION", "us-west-1")  # Default region if not set

# AWS Clients
logs_client = boto3.client("logs")


def lambda_handler(event, context):
    try:
        log_groups = logs_client.describe_log_groups()["logGroups"]
        
        for log_group in log_groups:
            log_group_name = log_group["logGroupName"]
            
            # Get subscription filters
            filters = logs_client.describe_subscription_filters(
                logGroupName=log_group_name
            )["subscriptionFilters"]
            
            existing_filters = [f["filterName"] for f in filters]
            
            if TARGET_SUBSCRIPTION_FILTER in existing_filters:
                log_status(log_group_name, "Compliant", "Already has target filter")
                continue
            
            if len(existing_filters) == 2:
                log_status(log_group_name, "Skipped", "Two filters already exist")
                continue
            
            # Apply subscription filter if 0 or 1 filter exists
            apply_subscription_filter(log_group_name)
        
        result_message = "SUCCESS: Execution completed. Check the log group for details."
        print(result_message)
        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": result_message,
                "cloudwatch_logs": get_log_group_link(LOG_GROUP_NAME)
            })
        }
    
    except Exception as e:
        log_error("Lambda Execution", str(e))
        result_message = "FAILURE: An error occurred. Check the log group for details."
        print(result_message)
        return {
            "statusCode": 500,
            "body": json.dumps({
                "message": result_message,
                "cloudwatch_logs": get_log_group_link(LOG_GROUP_NAME)
            })
        }


def apply_subscription_filter(log_group_name):
    """Applies the subscription filter if it is missing"""
    try:
        logs_client.put_subscription_filter(
            logGroupName=log_group_name,
            filterName=TARGET_SUBSCRIPTION_FILTER,
            filterPattern="",
            destinationArn=DESTINATION_ARN,
        )
        log_status(log_group_name, "Updated", "Subscription filter applied")
    
    except Exception as e:
        log_error(log_group_name, str(e))


def log_status(log_group_name, status, reason):
    """Logs compliance status and skipped reasons"""
    log_stream_name = f"compliance_status/{datetime.datetime.utcnow().strftime('%Y-%m-%d')}"
    
    try:
        # Ensure log stream exists
        logs_client.create_log_stream(logGroupName=LOG_GROUP_NAME, logStreamName=log_stream_name)
    except logs_client.exceptions.ResourceAlreadyExistsException:
        pass  # Log stream already exists
    
    log_event = {
        "timestamp": int(datetime.datetime.utcnow().timestamp() * 1000),
        "message": json.dumps({
            "log_group": log_group_name,
            "status": status,
            "reason": reason,
            "timestamp": str(datetime.datetime.utcnow()),
            "cloudwatch_logs": get_log_group_link(log_group_name)
        })
    }
    
    logs_client.put_log_events(
        logGroupName=LOG_GROUP_NAME,
        logStreamName=log_stream_name,
        logEvents=[log_event]
    )
    
    print(f"Logged status for {log_group_name}: {status} - {reason}")


def log_error(context, error_message):
    """Logs errors to CloudWatch"""
    log_stream_name = f"errors/{datetime.datetime.utcnow().strftime('%Y-%m-%d')}"
    
    try:
        logs_client.create_log_stream(logGroupName=LOG_GROUP_NAME, logStreamName=log_stream_name)
    except logs_client.exceptions.ResourceAlreadyExistsException:
        pass  # Log stream already exists
    
    log_event = {
        "timestamp": int(datetime.datetime.utcnow().timestamp() * 1000),
        "message": json.dumps({
            "context": context,
            "error": error_message,
            "timestamp": str(datetime.datetime.utcnow()),
            "cloudwatch_logs": get_log_group_link(LOG_GROUP_NAME)
        })
    }
    
    logs_client.put_log_events(
        logGroupName=LOG_GROUP_NAME,
        logStreamName=log_stream_name,
        logEvents=[log_event]
    )
    
    print(f"Logged error: {context} - {error_message}")


def get_log_group_link(log_group_name):
    """Generates a clickable link to the CloudWatch log group."""
    return f"https://{AWS_REGION}.console.aws.amazon.com/cloudwatch/home?region={AWS_REGION}#logsV2:log-groups/log-group/{log_group_name.replace('/', '$252F')}"


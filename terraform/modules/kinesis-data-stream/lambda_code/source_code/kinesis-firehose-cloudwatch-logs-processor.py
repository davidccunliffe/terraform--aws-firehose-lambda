import os
import json
import gzip
import time
import boto3
import logging
from botocore.exceptions import BotoCoreError, ClientError

def get_env_var(env_name: str) -> str:
    value = os.getenv(env_name)
    if value is None:
        raise EnvironmentError(f"Environment variable {env_name} not found")
    return value

def get_env_int(env_name: str) -> int:
    value = os.getenv(env_name)
    if value is None:
        raise EnvironmentError(f"Environment variable {env_name} not found")
    try:
        return int(value)
    except ValueError:
        raise ValueError(f"Cannot parse {env_name} to int")

def decompress_gzip(data: bytes) -> bytes:
    return gzip.decompress(data)

def get_kinesis_shard_iterator(client, stream_name: str):
    response = client.describe_stream(StreamName=stream_name)
    shard_id = response['StreamDescription']['Shards'][0]['ShardId']
    
    timestamp = int(time.time() - get_env_int("HOURS_FROM_START") * 3600)
    iterator_response = client.get_shard_iterator(
        StreamName=stream_name,
        ShardId=shard_id,
        ShardIteratorType='AT_TIMESTAMP',
        Timestamp=timestamp
    )
    return iterator_response['ShardIterator']

def process_records(client, kinesis_client, logs_client):
    stream_name = get_env_var("KINESIS_STREAM_NAME")
    shard_iterator = get_kinesis_shard_iterator(kinesis_client, stream_name)
    stop_count = 0
    message_batch = {}
    
    while True:
        response = kinesis_client.get_records(ShardIterator=shard_iterator)
        records = response.get("Records", [])
        
        if not records:
            time.sleep(1)
            stop_count += 1
            if stop_count > 20:
                return
            continue
        
        for record in records:
            try:
                decompressed_data = decompress_gzip(record["Data"])
                message = json.loads(decompressed_data)
                log_group = message["logGroup"]
                log_stream = message["logStream"]
                log_events = message["logEvents"]
                
                if log_stream not in message_batch:
                    message_batch[log_stream] = message
                    if len(message_batch) > 50:
                        post_batch(logs_client, message_batch)
                else:
                    message_batch[log_stream]["logEvents"].extend(log_events)
                    if len(message_batch[log_stream]["logEvents"]) > 120:
                        post_batch(logs_client, message_batch)
            except Exception as e:
                logging.error(f"Error processing record: {e}")
        
        post_batch(logs_client, message_batch)
        shard_iterator = response.get("NextShardIterator")
        if not shard_iterator:
            break
        stop_count += 1
        if stop_count > 20:
            return

def post_batch(logs_client, message_batch):
    if not message_batch:
        return
    
    for log_stream, message in message_batch.items():
        try:
            put_to_cloudwatch(logs_client, message)
        except Exception as e:
            logging.error(f"Failed to put logs to CloudWatch: {e}")
    message_batch.clear()

def put_to_cloudwatch(logs_client, message):
    log_group = message["logGroup"]
    log_stream = message["logStream"]
    log_events = message["logEvents"]
    log_events.sort(key=lambda e: e["timestamp"])
    
    try:
        logs_client.put_log_events(
            logGroupName=log_group,
            logStreamName=log_stream,
            logEvents=log_events
        )
    except ClientError as e:
        if e.response["Error"]["Code"] == "InvalidParameterException":
            midpoint = len(log_events) // 2
            put_to_cloudwatch(logs_client, {"logGroup": log_group, "logStream": log_stream, "logEvents": log_events[:midpoint]})
            put_to_cloudwatch(logs_client, {"logGroup": log_group, "logStream": log_stream, "logEvents": log_events[midpoint:]})
        else:
            raise

def lambda_handler(event, context):
    session = boto3.Session()
    kinesis_client = session.client("kinesis")
    logs_client = session.client("logs")
    
    process_records(session, kinesis_client, logs_client)
    return {"status": "success"}

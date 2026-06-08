import json
import logging

# Set up logging to CloudWatch
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Triggered by an S3 upload event.
    Logs the event and returns a success message.
    """
    logger.info("Received S3 event: %s", json.dumps(event, indent=2))

    # Extract bucket and key from the event
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        logger.info(f"Image received: {key} in bucket {bucket}")

    return {
        "statusCode": 200,
        "body": json.dumps("Processing successful")
    }

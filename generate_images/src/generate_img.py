import json
import base64
import logging
import boto3
from os import getenv
from datetime import datetime

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Required environment variables
BUCKET_NAME = getenv("S3_BUCKET_NAME", "default-bucket-name")

# Defaults for foundation model and other parameters
AWS_REGION = getenv("AWS_REGION", "us-east-1")
FOUNDATION_MODEL_ID = getenv("FOUNDATION_MODEL_ID", "amazon.nova-canvas-v1:0")
CFGSCALE_OF_IMAGE = int(getenv("CFGSCALE_OF_IMAGE", 8))
QUALITY_OF_IMAGE = getenv("QUALITY_OF_IMAGE", "standard")
NUMBER_OF_IMAGES = int(getenv("NUMBER_OF_IMAGES", 1))
HEIGHT_OF_IMAGE = int(getenv("HEIGHT_OF_IMAGE", 720))
WIDTH_OF_IMAGE = int(getenv("WIDTH_OF_IMAGE", 1280))
PRESIGNED_URL_EXPIRES_IN = int(getenv("PRESIGNED_URL_EXPIRES_IN", 3600))

# Initialize AWS clients
s3 = boto3.client("s3", region_name="us-east-2",
                  endpoint_url="https://s3.us-east-2.amazonaws.com")
bedrock_rtime = boto3.client("bedrock-runtime", region_name="us-east-1")


def lambda_handler(event, context):
    try:
        input_prompt = event.get('prompt', 'The cat on beach')
        logger.info(f"Received prompt: {input_prompt}")

        kwargs = {
            "modelId": FOUNDATION_MODEL_ID,
            "contentType": "application/json",
            "accept": "application/json",
            "body": json.dumps({
                "textToImageParams": {"text": input_prompt},
                "taskType": "TEXT_IMAGE",
                "imageGenerationConfig": {
                    "cfgScale": CFGSCALE_OF_IMAGE,
                    "seed": int(datetime.now().timestamp()) % 100000,
                    "quality": QUALITY_OF_IMAGE,
                    "width": WIDTH_OF_IMAGE,
                    "height": HEIGHT_OF_IMAGE,
                    "numberOfImages": NUMBER_OF_IMAGES
                }
            })
        }

        logger.info(
            f"Calling Bedrock model: {FOUNDATION_MODEL_ID} with parameters: {kwargs}")
        response = bedrock_rtime.invoke_model(**kwargs)
        response_body = json.loads(response.get('body').read())

        image_data = response_body["images"][0]
        image_bytes = base64.b64decode(image_data)

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        sanitized_prompt = input_prompt.replace(" ", "_").replace(
            ":", "").replace("/", "").replace("\\", "")[:50]
        image_key = f"generated_images/{sanitized_prompt}_{timestamp}.png"

        logger.info(
            f"Uploading image to S3 bucket '{BUCKET_NAME}' with key '{image_key}'")
        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=image_key,
            Body=image_bytes,
            ContentType="image/png"
        )

        logger.info(
            f"Generating pre-signed URL (expires in {PRESIGNED_URL_EXPIRES_IN}s)")
        presigned_url = s3.generate_presigned_url(
            "get_object",
            Params={"Bucket": BUCKET_NAME, "Key": image_key},
            ExpiresIn=PRESIGNED_URL_EXPIRES_IN
        )

        logger.info("Successfully generated image and URL.")
        return {
            "statusCode": 200,
            "body": presigned_url
        }

    except Exception as e:
        logger.error(f"Error during image generation: {e}", exc_info=True)
        return {
            "statusCode": 500,
            "body": json.dumps("An error occurred. Check the logs for more details.")
        }
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
s3 = boto3.client("s3", region_name="us-east-1")
bedrock_rtime = boto3.client("bedrock-runtime", region_name="us-east-1")


def generate_html_page(presigned_url="n/a", generated_sales_text="default"):
    logger.info(f"Generating sale page with URL: {presigned_url} and text: {generated_sales_text}")
    return f'''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>S3 PNG Gallery</title>
  <style>
    body {{
      font-family: sans-serif;
      text-align: center;
      padding: 2rem;
      background-color: #f9f9f9;
    }}
    img {{
      max-width: 100%;
      height: auto;
      margin: 1rem;
      border: 1px solid #ccc;
      box-shadow: 2px 2px 5px rgba(0,0,0,0.1);
    }}
  </style>
</head>
<body>
  <h1>PNG Gallery from S3</h1>
  <img src="{presigned_url}" alt="Generated Image">
  <h2>"{generated_sales_text}"</h2>
</body>
</html>'''


def generate_presigned_url(bucket_name, key, expires=PRESIGNED_URL_EXPIRES_IN):
    try:
        logger.info(
            f"Generating pre-signed URL for {key} in bucket {bucket_name}, expires in {expires}")
        return s3.generate_presigned_url(
            "get_object",
            Params={"Bucket": bucket_name, "Key": key},
            ExpiresIn=expires
        )
    except Exception as e:
        logger.error(f"Error generating pre-signed URL: {e}", exc_info=True)
        raise e


def upload_to_s3(bucket_name, key, data, content_type):
    try:
        logger.info(f"Uploading {key} to bucket {bucket_name}")
        s3.put_object(
            Bucket=bucket_name,
            Key=key,
            Body=data,
            ContentType=content_type
        )
        logger.info(f"Successfully uploaded {key} to {bucket_name}")
    except Exception as e:
        logger.error(f"Error uploading to S3: {e}", exc_info=True)
        raise e


def generate_img(prompt, foundation_model_id):
    try:
        kwargs = {
            "modelId": foundation_model_id,
            "contentType": "application/json",
            "accept": "application/json",
            "body": json.dumps({
                "textToImageParams": {"text": prompt},
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
        logger.info(f"Generating image with prompt: {kwargs}")
        response = bedrock_rtime.invoke_model(**kwargs)
        response_body = json.loads(response.get('body').read())
        image_data = response_body["images"][0]
        return base64.b64decode(image_data)
    except Exception as e:
        logger.error(f"Error generating image: {e}", exc_info=True)
        raise e


def lambda_handler(event, context):
    input_prompt = ''
    text = ''
    parameters = event.get('parameters', [])
    for param in parameters:
        if param.get("name") == "text":
            text = param.get("value", '')
        elif param.get("name") == "prompt":
            input_prompt = param.get("value", '')

    logger.info(f"Event received: {json.dumps(event)}")
    logger.info(f"Received prompt: {input_prompt}, text: {text}")

    image_bytes = generate_img(input_prompt, FOUNDATION_MODEL_ID)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    sanitized_prompt = input_prompt.replace(" ", "_").replace(":", "").replace("/", "").replace("\\", "")[:50]
    s3_img_key = f"generated_images/{sanitized_prompt}/{timestamp}.png"
    upload_to_s3(BUCKET_NAME, s3_img_key, image_bytes, "image/png")

    s3_img_presigned_url = generate_presigned_url(BUCKET_NAME, s3_img_key, PRESIGNED_URL_EXPIRES_IN)
    html_content = generate_html_page(s3_img_presigned_url, text)
    html_key = f"pages/{sanitized_prompt}/{timestamp}/index.html"
    upload_to_s3(BUCKET_NAME, html_key, html_content, "text/html")

    html_presigned_url = generate_presigned_url(BUCKET_NAME, html_key, PRESIGNED_URL_EXPIRES_IN)
    logger.info(f"Generated HTML page {html_presigned_url}")


    # Prepare the response body with JSON serialization
    message_version = event.get('messageVersion', '')
    session_attributes = event.get('sessionAttributes')
    prompt_session_attributes = event.get('promptSessionAttributes')

    response_body = {
        'TEXT': {
            'body': html_presigned_url
        }
    }

    function_response = {
        'actionGroup': event['actionGroup'],
        'function': event['function'],
        'functionResponse': {
            'responseBody': response_body
        }
    }

    response = {
        'messageVersion': message_version,
        'response': function_response,
        'sessionAttributes': session_attributes,
        'promptSessionAttributes': prompt_session_attributes
    }

    logger.info(
        f"Response: {json.dumps(response)}")
    return response
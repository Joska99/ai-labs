# AI Sale Page Generator

![Architecture](./svg/architecture.drawio.svg)

## Overview

AI-powered system that generates promotional sale pages for grocery stores using AWS Bedrock agents and image generation.

## Architecture

1. **User Request** → Lambda with sale details
2. **Bedrock Agent** processes request using knowledge base
3. **Image Generation** via Nova Canvas model
4. **S3 Storage** for generated content
5. **Pre-signed URL** returned for access

## Features

- **Bedrock Agent** with sales knowledge base
- **Image Generation** for promotional materials
- **OpenSearch Serverless** vector database
- **Automated Infrastructure** via Terraform

## Components

### Lambda Function
- Generates sale promotional images
- Uses Amazon Nova Canvas model
- Configurable image parameters

### Bedrock Agent
- Processes sale content requests
- Knowledge base with FreshMart product data
- Generates contextual image prompts

### Infrastructure
- S3 buckets for storage and knowledge base
- OpenSearch Serverless collection
- IAM roles and policies
- Lambda layers for dependencies

## Usage

### Deploy Infrastructure
```bash
make up
```

### Test Request
```json
{
    "prompt": "generate prompt to generate image for grocery store sale"
}
```

### Example Output
Pre-signed URL to generated promotional image with:
- Product pricing overlays
- Store branding (FreshMart)
- Sale dates and themes
- Professional layout

## Configuration

Key environment variables:
- `S3_BUCKET_NAME`: Storage bucket
- `FOUNDATION_MODEL_ID`: Bedrock model (default: nova-canvas-v1:0)
- `IMAGE_DIMENSIONS`: 1280x720 (configurable)

## Files

- `src/generate_sale_page.py` - Lambda function
- `terraform/` - Infrastructure as code
- `sales/` - Knowledge base content
- `tests/` - Test prompts
- `Makefile` - Deployment automation

## Requirements

- AWS CLI configured
- Terraform >= 1.0.7
- Python 3.13
- Make utility
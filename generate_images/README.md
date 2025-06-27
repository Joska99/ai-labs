# Ai-Image-Generator

![Custom Badge](./svg/architecture.drawio.svg)

1. User send Request to Lambda
```json
{
    "prompt": "A futuristic city with flying cars at sunset"
}
```

2. Lambda sends the prompt to AWS bedrock Model to generate image

3. Lambda put generated image to s3 bucket

4. Lambda generate PreSigned URL for newly generated image

5. Lambda return the PreSigned URL

## Test

- [Prompts](./test/test.json)
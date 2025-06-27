data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

locals {
  ENV                 = var.ENV
  PROJECT_NAME        = var.PROJECT_NAME
  DEFAULT_DESCRIPTION = "${local.PROJECT_NAME}-${local.ENV}"

  LAMBDAS_LAYERS = {
    for lambda in var.lambdas :
    lambda.function_name => try(
      [for layer in lookup(lambda, "layers", []) : module.lambda_layers[layer].lambda_layer_arn],
      []
    )
  }

  S3_ALLOW_ACCOUNT_ACCESS_POLICY = {
    for bucket in var.s3_buckets : bucket.name => {
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "AllowAccountAccess"
          Effect = "Allow"
          Principal = {
            AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
          }
          Action = "s3:*"
          Resource = [
            "arn:${data.aws_partition.current.partition}:s3:::${bucket.name}",
            "arn:${data.aws_partition.current.partition}:s3:::${bucket.name}/*"
          ]
        }
      ]
    }
  }

  DEFAULT_TAGS = {
    project_name = local.PROJECT_NAME
    env          = local.ENV
    deployed_by  = element(split("/", data.aws_caller_identity.current.arn), -1)
  }
}

module "lambda_functions" {
  source = "terraform-aws-modules/lambda/aws"

  for_each = { for lambda in var.lambdas : lambda.function_name => lambda }

  create_layer = false

  function_name          = each.value.function_name
  runtime                = each.value.runtime
  handler                = each.value.handler
  local_existing_package = each.value.local_existing_package

  create_package = each.value.create_package
  source_path    = each.value.source_path
  store_on_s3    = each.value.store_on_s3
  s3_bucket      = each.value.s3_bucket

  environment_variables = each.value.environment_variables

  description   = each.value.description != "" ? each.value.description : "${local.DEFAULT_DESCRIPTION}"
  architectures = each.value.architectures
  memory_size   = each.value.memory_size
  timeout       = each.value.timeout
  publish       = each.value.publish

  cloudwatch_logs_log_group_class   = each.value.cloudwatch_logs_log_group_class
  cloudwatch_logs_retention_in_days = each.value.cloudwatch_logs_retention_in_days
  logging_log_group                 = each.value.logging_log_group != "" ? each.value.logging_log_group : "${local.PROJECT_NAME}/Lambda/${local.ENV}/${each.value.function_name}-log-group"

  layers = local.LAMBDAS_LAYERS[each.value.function_name]

  create_current_version_allowed_triggers = each.value.create_current_version_allowed_triggers
  allowed_triggers = {
    bedrock_agent = {
      function_name = each.value.function_name
      source_arn    = "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:agent/*"
      statement_id  = "AllowBedrockInvokeLambda"
      action        = "lambda:InvokeFunction"
      principal     = "bedrock.amazonaws.com"
    }
  }

  tags = merge(
    each.value.tags,
    local.DEFAULT_TAGS
  )

  create_role = each.value.create_role
  role_name   = each.value.role_name != "" ? each.value.role_name : "${local.PROJECT_NAME}-${local.ENV}-${each.value.function_name}-role"

  attach_cloudwatch_logs_policy = each.value.attach_cloudwatch_logs_policy
  attach_network_policy         = each.value.attach_network_policy
  attach_policy_statements      = each.value.attach_policy_statements
  policy_statements = {
    invokeNova = {
      effect    = "Allow"
      actions   = ["bedrock:InvokeModel"]
      resources = ["arn:${data.aws_partition.current.partition}:bedrock:us-east-1::foundation-model/amazon.nova-canvas-v1:0"]
    },
    put_to_s3 = {
      effect    = "Allow"
      actions   = ["s3:PutObject", "s3:GetObject"]
      resources = ["arn:${data.aws_partition.current.partition}:s3:::ai-generated-images-central-dev/*"]
    },
  }
}


module "lambda_layers" {
  source = "terraform-aws-modules/lambda/aws"

  for_each = { for layer in var.lambda_layers : layer.layer_name => layer }

  create_layer   = true
  create_package = each.value.create_package

  layer_name             = each.value.layer_name
  local_existing_package = each.value.local_existing_package

  description              = each.value.description != "" ? each.value.description : "${local.DEFAULT_DESCRIPTION}"
  license_info             = each.value.license_info
  compatible_runtimes      = each.value.compatible_runtimes
  compatible_architectures = each.value.compatible_architectures
}


module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"

  for_each = { for bucket in var.s3_buckets : bucket.name => bucket }

  bucket = each.value.name

  attach_policy = each.value.attach_policy_statements
  policy        = jsonencode(local.S3_ALLOW_ACCOUNT_ACCESS_POLICY[each.value.name])

  tags = merge(
    each.value.tags,
    local.DEFAULT_TAGS
  )
}

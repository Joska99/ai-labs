data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

locals {
  ENV                 = var.env
  PROJECT_NAME        = var.project_name
  DEFAULT_DESCRIPTION = "${local.PROJECT_NAME}-${local.ENV}"

  LAMBDA_FUNCTIONS_ARN = try({
    for lambda in var.lambdas :
    lambda.name => "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:${lambda.name}"
  }, [])

  LAMBDAS_LAYERS = try({
    for lambda in var.lambdas :
    lambda.name => try(
      [for layer in lookup(lambda, "layers", []) : module.lambda_layers[layer].lambda_layer_arn],
      []
    )
  }, [])

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

  OSS_ALLOW_KB_ROLE_ACCESS_POLICY = {
    for collection in var.oss_collections : collection.name => {
      "Rules" : [
        {
          "Resource" : [
            "collection/${collection.name}"
          ],
          "Permission" : [
            "aoss:DescribeCollectionItems",
            "aoss:CreateCollectionItems",
            "aoss:UpdateCollectionItems"
          ],
          "ResourceType" : "collection"
        },
        {
          "Resource" : [
            "index/${collection.name}/*"
          ],
          "Permission" : [
            "aoss:UpdateIndex",
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
            "aoss:WriteDocument",
            "aoss:CreateIndex"
          ],
          "ResourceType" : "index"
        }
      ],
      "Principal" : [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/generate-sale-page-agent-kb-role",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/joska-admin"
      ],
      "Description" : "Access policy for Bedrock Knowledge Base"
    }
  }

  DEFAULT_TAGS = {
    project_name = local.PROJECT_NAME
    env          = local.ENV
    deployed_by  = element(split("/", data.aws_caller_identity.current.arn), -1)
    terraform    = "true"
  }
}


module "bedrock_agents" {
  depends_on = [
    module.oss_collections,
    opensearch_index.index,
    module.s3_buckets,
    aws_s3_object.object
  ]
  source   = "./modules/bedrock"
  for_each = { for bedrock_agent in var.bedrock_agents : bedrock_agent.name => bedrock_agent }

  name                  = each.value.name
  llm                   = each.value.llm
  desc                  = each.value.desc != "" ? each.value.desc : "${local.DEFAULT_DESCRIPTION}"
  instruction           = each.value.instruction
  idle_session_ttl_in_s = each.value.idle_session_ttl_in_s

  agent_ag_name                       = try(each.value.agent_ag.name, null)
  agent_ag_version                    = try(each.value.agent_ag.version, null)
  agent_ag_description                = try(each.value.agent_ag.description, "${local.DEFAULT_DESCRIPTION}")
  agent_ag_skip_resource_in_use_check = try(each.value.agent_ag.skip_resource_in_use_check, null)
  agent_ag_lambda_arn                 = try(local.LAMBDA_FUNCTIONS_ARN["${each.value.agent_ag.lambda_name}"], null)
  agent_ag_function_schemas           = try(each.value.agent_ag.function_schema.functions, null)

  agent_kb_name                                                   = try(each.value.agent_kb.name, null)
  agent_kb_kb_data_source_type                                    = try(each.value.agent_kb.kb_data_source.type, null)
  agent_kb_kb_data_source_s3_bucket_name                          = try(each.value.agent_kb.kb_data_source.s3_bucket_name, null)
  agent_kb_kb_config_type                                         = try(each.value.agent_kb.kb_config.type, null)
  agent_kb_kb_config_vector_kb_config_embedding_model_name        = try(each.value.agent_kb.kb_config.vector_kb_config.embedding_model_name, null)
  agent_kb_storage_config_type                                    = try(each.value.agent_kb.storage_config.type, null)
  agent_kb_storage_config_oss_config_collection_arn               = try(module.oss_collections[each.value.agent_kb.storage_config.oss_config.collection_name].arn, null)
  agent_kb_storage_config_oss_config_vector_index_name            = try(each.value.agent_kb.storage_config.oss_config.vector_index_name, null)
  agent_kb_storage_config_oss_config_field_mapping_vector_field   = try(each.value.agent_kb.storage_config.oss_config.field_map.vector_field, null)
  agent_kb_storage_config_םss_config_field_mapping_text_field     = try(each.value.agent_kb.storage_config.oss_config.field_map.text_field, null)
  agent_kb_storage_config_oss_config_field_mapping_metadata_field = try(each.value.agent_kb.storage_config.oss_config.field_map.metadata_field, null)

  tags = merge(
    each.value.tags,
    local.DEFAULT_TAGS
  )
}


module "oss_collections" {
  source   = "terraform-aws-modules/opensearch/aws//modules/collection"
  for_each = { for collection in var.oss_collections : collection.name => collection }

  name        = each.value.name
  type        = each.value.type
  description = each.value.description != "" ? each.value.description : local.DEFAULT_DESCRIPTION

  create_access_policy  = each.value.create_access_policy
  access_policy         = local.OSS_ALLOW_KB_ROLE_ACCESS_POLICY[each.value.name]
  create_network_policy = each.value.create_network_policy
  network_policy = {
    AllowFromPublic = each.value.network_policy.AllowFromPublic
  }


  tags = merge(
    each.value.tags,
    local.DEFAULT_TAGS
  )
}

# TODO modify to module
resource "opensearch_index" "index" {
  depends_on = [module.oss_collections]
  # for_each   = { for index in var.oss_collection_indexes : index.name => index }

  name                           = "bedrock-knowledge-base-default-index"
  number_of_shards               = "2"
  number_of_replicas             = "0"
  index_knn                      = true
  index_knn_algo_param_ef_search = "512"
  force_destroy                  = true
  mappings                       = <<-EOF
    {
      "properties": {
        "bedrock-knowledge-base-default-vector": {
          "type": "knn_vector",
          "dimension": 1024,
          "method": {
            "name": "hnsw",
            "engine": "faiss",
            "parameters": {
              "m": 16,
              "ef_construction": 512
            },
            "space_type": "l2"
          }
        },
        "AMAZON_BEDROCK_METADATA": {
          "type": "text",
          "index": "false"
        },
        "AMAZON_BEDROCK_TEXT_CHUNK": {
          "type": "text",
          "index": "true"
        }
      }
    }
  EOF
}


module "lambda_functions" {
  depends_on = [module.lambda_layers]
  source     = "terraform-aws-modules/lambda/aws"
  for_each   = { for lambda in var.lambdas : lambda.name => lambda }

  create_layer   = false
  create_package = each.value.create_package
  source_path    = each.value.source_path
  store_on_s3    = each.value.store_on_s3
  s3_bucket      = each.value.s3_bucket

  function_name                     = each.value.name
  description                       = each.value.description != "" ? each.value.description : "${local.DEFAULT_DESCRIPTION}"
  runtime                           = each.value.runtime
  handler                           = each.value.handler
  local_existing_package            = each.value.local_zip
  environment_variables             = each.value.env
  architectures                     = each.value.arch
  memory_size                       = each.value.memory
  timeout                           = each.value.timeout
  publish                           = each.value.publish
  layers                            = local.LAMBDAS_LAYERS[each.value.name]
  attach_cloudwatch_logs_policy     = each.value.cw_attach_logs_policy
  cloudwatch_logs_log_group_class   = each.value.cw_log_group_class
  cloudwatch_logs_retention_in_days = each.value.cw_logs_retention_in_d
  logging_log_group                 = each.value.cw_logging_log_group != "" ? each.value.cw_logging_log_group : "${local.PROJECT_NAME}/Lambda/${local.ENV}/${each.value.name}-log-group"


  attach_network_policy                   = each.value.attach_network_policy
  create_current_version_allowed_triggers = each.value.create_current_version_allowed_triggers
  allowed_triggers = {
    # TODO pass agent id as var
    bedrock_agent = {
      function_name = each.value.name
      source_arn    = "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:agent/*"
      statement_id  = "AllowBedrockInvokeLambda"
      action        = "lambda:InvokeFunction"
      principal     = "bedrock.amazonaws.com"
    }
  }

  create_role              = each.value.create_role
  role_name                = each.value.role_name != "" ? each.value.role_name : "${local.PROJECT_NAME}-${local.ENV}-${each.value.name}-role"
  attach_policy_statements = each.value.attach_policy_statements

  # TODO pass policy_statements (but not full arn in var) name as var
  policy_statements = {
    invokeNova = {
      effect    = "Allow"
      actions   = ["bedrock:InvokeModel"]
      resources = ["arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.region}::foundation-model/amazon.nova-canvas-v1:0"]
    },
    put_to_s3 = {
      effect    = "Allow"
      actions   = ["s3:PutObject", "s3:GetObject"]
      resources = ["arn:${data.aws_partition.current.partition}:s3:::ai-gsp-pages-dev/*"]
    },
  }

  tags = merge(
    each.value.tags,
    local.DEFAULT_TAGS
  )
}


module "lambda_layers" {
  source   = "terraform-aws-modules/lambda/aws"
  for_each = { for layer in var.lambda_layers : layer.name => layer }

  create_layer             = true
  create_package           = each.value.create_package
  layer_name               = each.value.name
  local_existing_package   = each.value.local_zip
  description              = each.value.description != "" ? each.value.description : "${local.DEFAULT_DESCRIPTION}"
  license_info             = each.value.license
  compatible_runtimes      = each.value.compatible_runtimes
  compatible_architectures = each.value.compatible_arch
}


module "s3_buckets" {
  source   = "terraform-aws-modules/s3-bucket/aws"
  for_each = { for bucket in var.s3_buckets : bucket.name => bucket }

  bucket        = each.value.name
  attach_policy = each.value.attach_policy_statements
  policy        = jsonencode(local.S3_ALLOW_ACCOUNT_ACCESS_POLICY[each.value.name])

  tags = merge(
    each.value.tags,
    local.DEFAULT_TAGS
  )
}


resource "aws_s3_object" "object" {
  depends_on = [module.s3_buckets]
  for_each   = { for file in var.upload_files : file.s3_bucket_key => file }

  bucket = module.s3_buckets["${each.value.s3_bucket_name}"].s3_bucket_id
  key    = each.value.s3_bucket_key
  source = each.value.source_file
  etag   = filemd5("${each.value.source_file}")
}

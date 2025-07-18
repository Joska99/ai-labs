data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

locals {
  # Global Vars
  name                              = var.name
  bedrock_agent_name                = "${local.name}-agent"
  bedrock_agent_role_name           = "${local.bedrock_agent_name}-role"
  bedrock_agent_role_policy_name    = "${local.bedrock_agent_role_name}-policy"
  bedrock_agent_kb_role_name        = "${local.bedrock_agent_name}-kb-role"
  bedrock_agent_kb_role_policy_name = "${local.bedrock_agent_role_name}-kb-policy"

  bedrock_agent_arn    = "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:agent/*"
  foundation_model_arn = "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.region}::foundation-model/${var.llm}"

  default_tags = merge(
    {
      bedrock_module_by = "joska99"
    },
    var.tags
  )


  # Condition Vars
  create_agent_kb = try(var.agent_kb_name, null) != null ? 1 : 0
  create_agent_ag = try(var.agent_ag_name, null) != null ? 1 : 0


  # Policy Documents
  bedrock_agent_iam_assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = "${data.aws_caller_identity.current.account_id}"
          }
          ArnLike = {
            "AWS:SourceArn" = "${local.bedrock_agent_arn}"
          }
        }
      }
    ]
  })

  bedrock_agent_iam_role_policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "bedrock:InvokeModel"
        Resource = "${local.foundation_model_arn}"
      },
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = "${var.agent_ag_lambda_arn}"
      },
      {
        Effect   = "Allow"
        Action   = "bedrock:Retrieve"
        Resource = "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:knowledge-base/*"
      }
    ]
  })

  bedrock_agent_kb_iam_assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = "${data.aws_caller_identity.current.account_id}"
          }
          ArnLike = {
            "AWS:SourceArn" = "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:knowledge-base/*"
          }
        }
      }
    ]
  })

  bedrock_agent_kb_iam_role_policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "bedrock:InvokeModel"
        Resource = "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.region}::foundation-model/amazon.titan-embed-text-v2:0"
      },
      {
        Effect   = "Allow"
        Action   = "aoss:APIAccessAll"
        Resource = "arn:${data.aws_partition.current.partition}:aoss:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:collection/*"
      },
      {
        Effect = "Allow"
        Action = ["s3:ListBucket", "s3:GetObject"]
        Resource = [
          "arn:aws:s3:::${var.agent_kb_kb_data_source_s3_bucket_name}/*",
          "arn:aws:s3:::${var.agent_kb_kb_data_source_s3_bucket_name}"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "agent_role" {
  assume_role_policy = local.bedrock_agent_iam_assume_role_policy
  name               = local.bedrock_agent_role_name
  description        = "Default Role for Bedrock Agent ${local.name}"

  tags = merge(
    local.default_tags
  )
}

resource "aws_iam_role_policy" "agent_role_policy" {
  name   = local.bedrock_agent_role_policy_name
  role   = aws_iam_role.agent_role.id
  policy = local.bedrock_agent_iam_role_policy_document
}

resource "aws_bedrockagent_agent" "agent" {
  agent_name              = local.bedrock_agent_name
  agent_resource_role_arn = aws_iam_role.agent_role.arn
  foundation_model        = var.llm

  instruction                 = var.instruction != null ? var.instruction : null
  description                 = var.desc != null ? var.desc : null
  idle_session_ttl_in_seconds = var.idle_session_ttl_in_s != null ? var.idle_session_ttl_in_s : null

  tags = merge(
    var.tags != null ? var.tags : null,
    local.default_tags
  )
}

resource "aws_bedrockagent_agent_action_group" "agent_ag" {
  count = local.create_agent_ag

  action_group_name = var.agent_ag_name
  agent_id          = aws_bedrockagent_agent.agent.id
  agent_version     = var.agent_ag_version

  description                = var.agent_ag_description != null ? var.agent_ag_description : null
  skip_resource_in_use_check = var.agent_ag_skip_resource_in_use_check != null ? var.agent_ag_skip_resource_in_use_check : true
  action_group_state         = var.agent_ag_state != null ? var.agent_ag_state : null

  action_group_executor {
    lambda = var.agent_ag_lambda_arn != null ? var.agent_ag_lambda_arn : null
  }

  function_schema {
    member_functions {
      dynamic "functions" {
        for_each = var.agent_ag_function_schemas

        content {
          name        = functions.value.name
          description = functions.value.description != null ? functions.value.description : null

          dynamic "parameters" {
            for_each = functions.value.parameters

            content {
              map_block_key = parameters.value.map_block_key
              type          = parameters.value.type
              description   = parameters.value.description
              required      = parameters.value.required
            }
          }
        }
      }
    }
  }
}

resource "aws_iam_role" "agent_kb_role" {
  assume_role_policy = local.bedrock_agent_kb_iam_assume_role_policy
  name               = local.bedrock_agent_kb_role_name
  description        = "Default Role for Bedrock Agent Knowledge Base ${local.name}"

  tags = merge(
    local.default_tags
  )
}

resource "aws_iam_role_policy" "agent_kb_role_policy" {
  name   = local.bedrock_agent_kb_role_policy_name
  role   = aws_iam_role.agent_kb_role.id
  policy = local.bedrock_agent_kb_iam_role_policy_document
}

resource "aws_bedrockagent_knowledge_base" "agent_kb" {
  count = local.create_agent_kb

  name     = var.agent_kb_name
  role_arn = aws_iam_role.agent_kb_role.arn

  knowledge_base_configuration {
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:${data.aws_partition.current.partition}:bedrock:${data.aws_region.current.region}::foundation-model/${var.agent_kb_kb_config_vector_kb_config_embedding_model_name}"
    }
    type = var.agent_kb_kb_config_type
  }

  storage_configuration {
    type = var.agent_kb_storage_config_type

    opensearch_serverless_configuration {
      collection_arn    = var.agent_kb_storage_config_oss_config_collection_arn
      vector_index_name = var.agent_kb_storage_config_oss_config_vector_index_name
      field_mapping {
        vector_field   = var.agent_kb_storage_config_oss_config_field_mapping_vector_field
        text_field     = var.agent_kb_storage_config_םss_config_field_mapping_text_field
        metadata_field = var.agent_kb_storage_config_oss_config_field_mapping_metadata_field
      }
    }
  }
}

resource "aws_bedrockagent_data_source" "agent_kb_data_source" {
  depends_on = [aws_bedrockagent_knowledge_base.agent_kb[0]]
  count      = local.create_agent_kb

  knowledge_base_id = aws_bedrockagent_knowledge_base.agent_kb[0].id
  name              = "${var.agent_kb_name}-data-source"

  data_source_configuration {
    type = var.agent_kb_kb_data_source_type
    s3_configuration {
      bucket_arn = "arn:${data.aws_partition.current.partition}:s3:::${var.agent_kb_kb_data_source_s3_bucket_name}"
    }
  }
}

resource "aws_bedrockagent_agent_knowledge_base_association" "agent_kb_association" {
  depends_on = [aws_bedrockagent_agent.agent, aws_bedrockagent_knowledge_base.agent_kb[0]]
  count      = local.create_agent_kb

  agent_id             = aws_bedrockagent_agent.agent.id
  agent_version        = "DRAFT"
  knowledge_base_id    = aws_bedrockagent_knowledge_base.agent_kb[0].id
  knowledge_base_state = "ENABLED"
  description          = "Knowledge base association for ${var.name}"
}

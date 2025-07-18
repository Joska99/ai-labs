variable "env" {
  description = "."
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "The name of your project."
  type        = string
  default     = "default"
}

variable "bedrock_agents" {
  description = "The agents."
  default     = null
  type = list(object({
    name                  = string
    llm                   = string
    instruction           = optional(string, "")
    desc                  = optional(string, "")
    idle_session_ttl_in_s = optional(number, 500)
    tags                  = optional(map(string), {})
    agent_kb = optional(object({
      name = string
      kb_data_source = optional(object({
        type           = optional(string, "S3")
        s3_bucket_name = optional(string, "default-bucket")
      }), {})
      kb_config = optional(object({
        type = optional(string, "VECTOR")
        vector_kb_config = optional(object({
          embedding_model_name = optional(string, "amazon.titan-embed-text-v2:0")
        }), {})
      }), {})
      storage_config = optional(object({
        type = optional(string, "OPENSEARCH_SERVERLESS")
        oss_config = optional(object({
          collection_name   = optional(string, "default-oss-collection")
          vector_index_name = optional(string, "bedrock-knowledge-base-default-index")
          field_map = optional(object({
            vector_field   = optional(string, "bedrock-knowledge-base-default-vector")
            text_field     = optional(string, "AMAZON_BEDROCK_TEXT_CHUNK")
            metadata_field = optional(string, "AMAZON_BEDROCK_METADATA")
          }), {})
        }), {})
      }), {})
    })),
    agent_ag = optional(object({
      name                       = string
      lambda_name                = optional(string, "")
      description                = optional(string, null)
      version                    = optional(string, "DRAFT")
      skip_resource_in_use_check = optional(bool, true)
      # action_group_state         = optional(string, "ENABLED")
      function_schema = optional(object({
        functions = list(object({
          name        = string
          description = string
          parameters = optional(list(object({
            map_block_key = string
            type          = string
            description   = optional(string)
            required      = bool
          })), [])
        }))
      }))
    }))
  }))
}

variable "oss_collections" {
  description = "OpenSearch Serverless collections for knowledge bases"
  default     = []
  type = list(object({
    name                  = string
    type                  = string
    description           = optional(string, "")
    create_network_policy = optional(bool, true)
    network_policy = optional(object({
      AllowFromPublic = optional(bool, true)
    }), {})
    create_access_policy = optional(bool, true)
    tags                 = optional(map(string), {})
  }))
}

variable "oss_collection_indexes" {
  description = "values for OpenSearch Serverless collection index"
  default     = []
  type = list(object({
    map                            = map(any)
    name                           = optional(string, "bedrock-knowledge-base-default-index")
    shards                         = optional(number, 2)
    replicas                       = optional(number, 0)
    index_knn                      = optional(bool, true)
    index_knn_algo_param_ef_search = optional(string, "512")
    force_destroy                  = optional(bool, true)
  }))
}

variable "lambdas" {
  description = "List of lambdas"
  default     = []
  type = list(object({
    name                                    = string
    runtime                                 = string
    handler                                 = string
    local_zip                               = string
    allowed_triggers                        = optional(string)
    create_package                          = optional(bool, false)
    source_path                             = optional(string, "")
    store_on_s3                             = optional(bool, false)
    s3_bucket                               = optional(string, "")
    env                                     = optional(map(string), {})
    description                             = optional(string, "")
    arch                                    = optional(list(string), ["x86_64"])
    memory                                  = optional(number, 128)
    timeout                                 = optional(number, 3)
    publish                                 = optional(bool, false)
    cw_log_group_class                      = optional(string, "STANDARD")
    cw_logs_retention_in_d                  = optional(number, 1)
    cw_logging_log_group                    = optional(string, "")
    cw_attach_logs_policy                   = optional(bool, true)
    layers                                  = optional(list(string), [])
    create_current_version_allowed_triggers = optional(bool, false)
    tags                                    = optional(map(string), {})
    create_role                             = optional(bool, true)
    role_name                               = optional(string, "")
    attach_network_policy                   = optional(bool, false)
    attach_policy_statements                = optional(bool, false)
    policy_statements                       = optional(map(string), {})
  }))
}

variable "lambda_layers" {
  description = "List of lambda layers"
  default     = []
  type = list(object({
    name                = string
    local_zip           = string
    create_package      = optional(bool, false)
    description         = optional(string, "")
    license             = optional(string, "")
    compatible_runtimes = optional(list(string), [])
    compatible_arch     = optional(list(string), ["x86_64"])
  }))
}

variable "s3_buckets" {
  description = "S3 buckets"
  default     = []
  type = list(object({
    name                     = string
    attach_policy_statements = optional(bool, true)
    tags                     = optional(map(string), {})
  }))
}

variable "upload_files" {
  description = "List of files to upload to S3 buckets"
  default     = []
  type = list(object({
    s3_bucket_key  = string
    s3_bucket_name = string
    source_file    = string
  }))
}

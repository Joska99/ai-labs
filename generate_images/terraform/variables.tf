variable "ENV" {
  description = "."
  type        = string
  default     = "dev"
}

variable "PROJECT_NAME" {
  description = "The name of your project."
  type        = string
  default     = "default"
}

variable "lambdas" {
  description = "List of lambdas"
  default     = []
  type = list(object({
    function_name                           = string
    runtime                                 = string
    handler                                 = string
    local_existing_package                  = string
    allowed_triggers                        = string
    create_package                          = optional(bool, false)
    source_path                             = optional(string, "")
    store_on_s3                             = optional(bool, false)
    s3_bucket                               = optional(string, "")
    environment_variables                   = optional(map(string), {})
    description                             = optional(string, "")
    architectures                           = optional(list(string), ["x86_64"])
    memory_size                             = optional(number, 128)
    timeout                                 = optional(number, 3)
    publish                                 = optional(bool, false)
    cloudwatch_logs_log_group_class         = optional(string, "STANDARD")
    cloudwatch_logs_retention_in_days       = optional(number, 1)
    logging_log_group                       = optional(string, "")
    layers                                  = optional(list(string), [])
    create_current_version_allowed_triggers = optional(bool, false)
    tags                                    = optional(map(string), {})
    create_role                             = optional(bool, true)
    role_name                               = optional(string, "")
    attach_cloudwatch_logs_policy           = optional(bool, true)
    attach_network_policy                   = optional(bool, false)
    attach_policy_statements                = optional(bool, false)
    policy_statements                       = optional(map(string), {})
  }))
}

variable "lambda_layers" {
  description = "List of lambda layers"
  default     = []
  type = list(object({
    layer_name               = string
    local_existing_package   = string
    create_package           = optional(bool, false)
    description              = optional(string, "")
    license_info             = optional(string, "")
    compatible_runtimes      = optional(list(string), [])
    compatible_architectures = optional(list(string), ["x86_64"])
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

# – Bedrock Agent –
variable "name" {
  description = "Name of the Bedrock agent."
  type        = string
  default     = null
}

variable "llm" {
  description = "Foundation model ID for the Bedrock agent."
  type        = string
  default     = null
}

variable "instruction" {
  description = "Instruction provided to the Bedrock agent."
  type        = string
  default     = null
}

variable "desc" {
  description = "Description for the Bedrock agent."
  type        = string
  default     = null
}

variable "idle_session_ttl_in_s" {
  description = "Time in seconds before an idle session expires."
  type        = number
  default     = null
}

variable "tags" {
  description = "Tags to associate with the Bedrock agent."
  type        = map(string)
  default     = null
}



# – Bedrock Agent Action Group –
variable "agent_ag_name" {
  description = "Name of the action group for the Bedrock agent."
  type        = string
  default     = null
}

variable "agent_ag_version" {
  description = "Version of the action group for the Bedrock agent."
  type        = string
  default     = null
}

variable "agent_ag_description" {
  description = "Description of the action group."
  type        = string
  default     = null
}

variable "agent_ag_skip_resource_in_use_check" {
  description = "Whether to skip resource in-use checks for the action group."
  type        = bool
  default     = null
}

# TODO: check this env always null
variable "agent_ag_state" {
  description = "State of the action group (e.g., ENABLED, DISABLED)."
  type        = string
  default     = null
}

variable "agent_ag_lambda_arn" {
  description = "State of the action group (e.g., ENABLED, DISABLED)."
  type        = string
  default     = null
}

variable "agent_ag_function_schemas" {
  description = "List of functions in the action group's function schema."
  type = list(object({
    name        = string
    description = optional(string)
    parameters = optional(list(object({
      map_block_key = string
      type          = string
      description   = optional(string)
      required      = bool
    })))
  }))
  default = null
}



# – Bedrock Knowledge Base –
variable "agent_kb_name" {
  description = "Name of the S3 bucket for the Bedrock knowledge base."
  type        = string
  default     = null
}

variable "agent_kb_kb_data_source_type" {
  description = "Type of the knowledge base data source (e.g., S3)."
  type        = string
  default     = null
}

variable "agent_kb_kb_data_source_s3_bucket_name" {
  description = "Name of the S3 bucket for the Bedrock knowledge base."
  type        = string
  default     = null
}

variable "agent_kb_kb_config_vector_kb_config_embedding_model_name" {
  description = "Name of the S3 bucket for the Bedrock knowledge base."
  type        = string
  default     = null
}

variable "agent_kb_kb_config_type" {
  description = "Name of the S3 bucket for the Bedrock knowledge base."
  type        = string
  default     = null
}

variable "agent_kb_storage_config_type" {
  description = "Name of the S3 bucket for the Bedrock knowledge base."
  type        = string
  default     = null
}

variable "agent_kb_storage_config_oss_config_collection_arn" {
  description = "Name of the S3 bucket for the Bedrock knowledge base."
  type        = string
  default     = null
}

variable "agent_kb_storage_config_oss_config_vector_index_name" {
  description = "Name of the S3 bucket for the Bedrock knowledge base."
  type        = string
  default     = null
}

variable "agent_kb_storage_config_oss_config_field_mapping_vector_field" {
  description = "Name of the S3 bucket for the Bedrock knowledge base."
  type        = string
  default     = null
}

variable "agent_kb_storage_config_םss_config_field_mapping_text_field" {
  description = "Name of the S3 bucket for the Bedrock knowledge base."
  type        = string
  default     = null
}

variable "agent_kb_storage_config_oss_config_field_mapping_metadata_field" {
  description = "Name of the S3 bucket for the Bedrock knowledge base."
  type        = string
  default     = null
}

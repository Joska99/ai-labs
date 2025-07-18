# Define variables
TF_BIN = terraform
TF_DIR = ./terraform
TF_VARS = '-var-file=../terraform.tfvars.json'
TF_PLAN_FILE ?= tf.plan
PY_REQUIREMENTS = ../src/requirements.txt
PY_REQUIREMENTS_ZIP = requirements.zip
PY_CODE = ./src/app.py
PY_ARTIFACT_ZIP = app.zip

# Default target
.DEFAULT_GOAL := help

# Install python packages and build zip artifacts
dep:
	@echo "Installing Python dependencies and building Lambda artifacts..."
	@echo "Clean previous builds"
	rm -rf packages ${PY_REQUIREMENTS_ZIP} ${PY_ARTIFACT_ZIP}
	@echo "Create folder for Lambda layer"
	mkdir -p packages/python
	cd packages && \
		pip install --upgrade -r ${PY_REQUIREMENTS} -t python && \
		find python -type d -name "__pycache__" -exec rm -rf {} + && \
		find python -type d -name "tests" -exec rm -rf {} + && \
		find python -type d -name "test" -exec rm -rf {} + && \
		find python -type d -name "*.dist-info" -exec rm -rf {} + && \
		find python -type d -name "*.egg-info" -exec rm -rf {} + && \
		zip -r9 ../${PY_REQUIREMENTS_ZIP} python
	@echo "Create zip for Lambda function code (no directory structure)"
	zip -9 ${PY_ARTIFACT_ZIP} ${PY_CODE} -j

# Initialize Terraform
init:
	@echo "Initializing Terraform..."
	cd $(TF_DIR) && $(TF_BIN) init -upgrade

# Plan Terraform deployment and save to plan file
plan:
	@echo "Planning Terraform changes..."
	cd $(TF_DIR) && $(TF_BIN) plan $(TF_VARS) -out=$(TF_PLAN_FILE)

# Apply the saved Terraform plan file
_apply:
	@echo "Applying Terraform plan file..."
	cd $(TF_DIR) && $(TF_BIN) apply -auto-approve $(TF_PLAN_FILE)

# Destroy Terraform infrastructure
destroy:
	@echo "Destroying Terraform infrastructure..."
	cd $(TF_DIR) && terraform state rm opensearch_index.index || true && $(TF_BIN) destroy $(TF_VARS) -auto-approve

# Clean up any Terraform-generated files
clean:
	@echo "Cleaning up Terraform files..."
	rm -rf $(TF_DIR)/.terraform/ $(TF_DIR)/*.tfstate $(TF_DIR)/*.tfstate.backup || true
	rm -rf $(TF_DIR)/.terraform.lock.hcl $(TF_DIR)/builds $(TF_DIR)/tf.plan || true
	rm -rf ${PY_REQUIREMENTS_ZIP} ${PY_ARTIFACT_ZIP} packages || true

# Format Terraform files
fmt:
	@echo "Formatting Terraform files..."
	cd $(TF_DIR) && $(TF_BIN) fmt

# Validate Terraform configuration
validate:
	@echo "Validating Terraform configuration..."
	cd $(TF_DIR) && $(TF_BIN) validate



# Combined command
up: init fmt validate dep plan _apply
down: destroy clean
apply: plan _apply

# Help command
help:
	@echo "Usage:"
	@echo "  make init           - Initialize Terraform"
	@echo "  make plan           - Plan Terraform deployment"
	@echo "  make _apply         - Apply Terraform changes"
	@echo "  make destroy        - Destroy Terraform infrastructure"
	@echo "  make fmt            - Format Terraform files"
	@echo "  make validate       - Validate Terraform configuration"
	@echo "  make clean          - Remove build artifacts and .terraform files"
	@echo "  make dep            - Install Python deps and zip packages"
	@echo "  make up             - Full pipeline: format, init, validate, build, plan, apply"

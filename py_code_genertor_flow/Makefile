STACK_NAME ?= my-bedrock-flow-stack
TEMPLATE_FILE ?= ./cloud_formation/flow.yaml
PARAMETERS_FILE ?= ./cloud_formation/parameters.json

define log
	@echo "[INFO] $(1)"
endef

deploy:
	@echo "[INFO] Creating stack $(STACK_NAME)..."
	aws cloudformation create-stack \
		--stack-name $(STACK_NAME) \
		--template-body file://$(TEMPLATE_FILE) \
		--parameters file://$(PARAMETERS_FILE) \
		--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM
	aws cloudformation wait stack-create-complete --stack-name $(STACK_NAME)
	@echo "[INFO] Stack created."

update:
	@echo "[INFO] Updating stack $(STACK_NAME)..."
	aws cloudformation update-stack \
		--stack-name $(STACK_NAME) \
		--template-body file://$(TEMPLATE_FILE) \
		--parameters file://$(PARAMETERS_FILE) \
		--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM

destroy:
	@echo "[INFO] Deleting stack $(STACK_NAME)..."
	aws cloudformation delete-stack --stack-name $(STACK_NAME)
	aws cloudformation wait stack-delete-complete --stack-name $(STACK_NAME)
	@echo "[INFO] Stack deleted."

status:
	@echo "[INFO] Checking stack status for $(STACK_NAME)..."
	aws cloudformation describe-stacks \
		--stack-name $(STACK_NAME) \
		--query "Stacks[0].StackStatus" \
		--output text 2>/dev/null || echo "STACK_NOT_FOUND"
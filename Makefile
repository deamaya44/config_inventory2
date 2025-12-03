# Makefile para gestión del Config Inventory Lambda

# Variables
TF_DIR = example
TERRAFORM = terraform
AWS_REGION ?= us-east-1

.PHONY: help init plan apply destroy validate fmt lint clean test invoke logs

# Mostrar ayuda
help:
	@echo "Comandos disponibles:"
	@echo "  init     - Inicializar Terraform"
	@echo "  plan     - Mostrar plan de ejecución de Terraform"
	@echo "  apply    - Aplicar cambios de Terraform"
	@echo "  destroy  - Destruir recursos de Terraform"
	@echo "  validate - Validar configuración de Terraform"
	@echo "  fmt      - Formatear archivos de Terraform"
	@echo "  lint     - Verificar sintaxis y mejores prácticas"
	@echo "  clean    - Limpiar archivos temporales"
	@echo "  test     - Ejecutar pruebas de la Lambda"
	@echo "  invoke   - Invocar la Lambda manualmente"
	@echo "  logs     - Mostrar logs recientes de la Lambda"

# Inicializar Terraform
init:
	@echo "Inicializando Terraform..."
	cd $(TF_DIR) && $(TERRAFORM) init

# Crear plan de ejecución
plan:
	@echo "Creando plan de ejecución..."
	cd $(TF_DIR) && $(TERRAFORM) plan

# Aplicar cambios
apply:
	@echo "Aplicando cambios..."
	cd $(TF_DIR) && $(TERRAFORM) apply

# Aplicar cambios automáticamente
apply-auto:
	@echo "Aplicando cambios automáticamente..."
	cd $(TF_DIR) && $(TERRAFORM) apply -auto-approve

# Destruir recursos
destroy:
	@echo "Destruyendo recursos..."
	cd $(TF_DIR) && $(TERRAFORM) destroy

# Validar configuración
validate:
	@echo "Validando configuración..."
	cd $(TF_DIR) && $(TERRAFORM) validate
	cd terraform && $(TERRAFORM) validate

# Formatear código
fmt:
	@echo "Formateando archivos..."
	$(TERRAFORM) fmt -recursive .

# Verificar sintaxis y mejores prácticas
lint:
	@echo "Verificando sintaxis..."
	$(TERRAFORM) fmt -check -recursive .
	cd $(TF_DIR) && $(TERRAFORM) validate
	cd terraform && $(TERRAFORM) validate

# Limpiar archivos temporales
clean:
	@echo "Limpiando archivos temporales..."
	find . -name "*.zip" -delete
	find . -name ".terraform" -type d -exec rm -rf {} +
	find . -name "terraform.tfstate*" -delete
	find . -name ".terraform.lock.hcl" -delete

# Probar la función Python localmente
test:
	@echo "Ejecutando pruebas locales..."
	python3 main.py

# Invocar la Lambda manualmente (requiere AWS CLI)
invoke:
	@echo "Invocando Lambda manualmente..."
	@FUNCTION_NAME=$$(cd $(TF_DIR) && $(TERRAFORM) output -raw lambda_function_name 2>/dev/null); \
	if [ -n "$$FUNCTION_NAME" ]; then \
		aws lambda invoke \
			--function-name $$FUNCTION_NAME \
			--payload '{"region":"$(AWS_REGION)","use_aggregator":true}' \
			--region $(AWS_REGION) \
			response.json && \
		cat response.json && rm response.json; \
	else \
		echo "Error: No se pudo obtener el nombre de la función. Asegúrate de que esté desplegada."; \
	fi

# Mostrar logs recientes de CloudWatch
logs:
	@echo "Mostrando logs recientes..."
	@LOG_GROUP=$$(cd $(TF_DIR) && $(TERRAFORM) output -raw cloudwatch_log_group 2>/dev/null); \
	if [ -n "$$LOG_GROUP" ]; then \
		aws logs tail $$LOG_GROUP --follow --region $(AWS_REGION); \
	else \
		echo "Error: No se pudo obtener el grupo de logs. Asegúrate de que esté desplegado."; \
	fi

# Mostrar outputs de Terraform
outputs:
	@echo "Outputs de Terraform:"
	cd $(TF_DIR) && $(TERRAFORM) output

# Crear archivo de variables si no existe
setup:
	@if [ ! -f $(TF_DIR)/terraform.tfvars ]; then \
		echo "Creando terraform.tfvars desde el ejemplo..."; \
		cp $(TF_DIR)/terraform.tfvars.example $(TF_DIR)/terraform.tfvars; \
		echo "Edita $(TF_DIR)/terraform.tfvars con tus valores específicos"; \
	else \
		echo "terraform.tfvars ya existe"; \
	fi

# Despliegue completo
deploy: setup init plan apply outputs

# Verificación completa
check: validate fmt lint

# Estado de los recursos
status:
	@echo "Estado de los recursos:"
	cd $(TF_DIR) && $(TERRAFORM) show -json | jq -r '.values.root_module.resources[] | select(.type == "aws_lambda_function") | .values.function_name'
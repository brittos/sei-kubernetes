include envlocal.env

ifeq ("$(MAKEFILE_MODO_VERBOSE)",  "true")
SHELL = sh -xv
endif

qtd := "2"
LOGS_SEGUIR=true

DIR := ${CURDIR}
CMD_CURL_SEI_LOGIN = curl -s -L -k $(APP_PROTOCOLO)://$(APP_HOST)/sei | grep "txtUsuario"
.DEFAULT_GOAL:=help

##@ Help
.PHONY: Lista de comandos disponiveis e descricao.
help: ## Lista de comandos disponiveis e descricao.
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Check Login
.PHONY: check
check: ## Acessa o SEI e verifica se esta respondendo a tela de login
	@echo "Vamos tentar acessar a pagina de login do SEI, vamos aguardar ate 95 segs."
	@for number in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37; do \
	    echo 'Tentando acessar...'; var=$$(echo $$($(CMD_CURL_SEI_LOGIN))); \
			if [ "$$var" != "" ]; then \
					echo 'Pagina respondeu com tela de login' ; \
					break ; \
			else \
			    echo 'Aguardando resposta ...'; \
			fi; \
			sleep 5; \
	done; \
	var=$$(echo $$($(CMD_CURL_SEI_LOGIN))); \
	if [ "$$var" == "" ]; then echo 'Pagina de login nao respondeu. Verifique. Abandonando execucao'; exit 1 ; fi;

##@ Build Image
.PHONY: build
build: ## Construir imagens do SEI
# To Do

##@ Push Image 
.PHONY: push
push: ## Enviar imagens para o Harbor Registry.
# To Do

##@ kubernetes tools
.PHONY: kubernetes_yaml
kubernetes_yaml: ## Montar os arquivos yaml para o Rancher Desktop kubernetes
	@echo "Vamos montar os arquivos yaml para o kubernetes. Apenas mysql e somente componentes essenciais..."
	@rm -rf orquestrators/rancher-kubernetes/topublish/configmaps.yaml \
	orquestrators/rancher-kubernetes/topublish/deploys-svc.yaml \
	orquestrators/rancher-kubernetes/topublish/ingress.yaml \
	orquestrators/rancher-kubernetes/topublish/jobs.yaml \
	orquestrators/rancher-kubernetes/topublish/pvc.yaml \
	orquestrators/rancher-kubernetes/topublish/statefullsets.yaml \
	orquestrators/rancher-kubernetes/topublish/secrets.yaml \
	orquestrators/rancher-kubernetes/topublish/registry.yaml \
	orquestrators/rancher-kubernetes/topublish/backup.yaml
	
	@envsubst < orquestrators/rancher-kubernetes/templates/configmaps-template.yaml > orquestrators/rancher-kubernetes/topublish/configmaps.yaml
	@envsubst < orquestrators/rancher-kubernetes/templates/deploys-svc-template.yaml > orquestrators/rancher-kubernetes/topublish/deploys-svc.yaml
	@envsubst < orquestrators/rancher-kubernetes/templates/ingress-template.yaml > orquestrators/rancher-kubernetes/topublish/ingress.yaml
	@envsubst < orquestrators/rancher-kubernetes/templates/jobs-template.yaml > orquestrators/rancher-kubernetes/topublish/jobs.yaml
	@envsubst < orquestrators/rancher-kubernetes/templates/pvc-template.yaml > orquestrators/rancher-kubernetes/topublish/pvc.yaml
	@envsubst < orquestrators/rancher-kubernetes/templates/statefullsets-template.yaml > orquestrators/rancher-kubernetes/topublish/statefullsets.yaml
	@envsubst < orquestrators/rancher-kubernetes/templates/registry-template.yaml > orquestrators/rancher-kubernetes/topublish/registry.yaml
	@envsubst < orquestrators/rancher-kubernetes/templates/letsencrypt-prod-template.yaml > orquestrators/rancher-kubernetes/topublish/letsencrypt-prod.yaml
	@envsubst < orquestrators/rancher-kubernetes/templates/backup-template.yaml > orquestrators/rancher-kubernetes/topublish/backup.yaml	
	@sh generatebase64.sh
	@echo "===================================================================================================================="
	@echo "Arquivos gerados no diretorio orquestrators/rancher-kubernetes/topublish"
	@echo "Verifique cada um antes de publicar"
	@echo "Como existem muitas variações de versões de kubernetes e orquestradores pode ser necessário algum ajuste adicional"
	@echo "Esses foram testados em um kubernetes 1.25.* embaixo de plataforma Rancher"
	@echo "Comece publicando o configmap, registry e o secret, depois os pvcs e em seguida os demais componentes"
	@echo "Como o codigo fonte do SEI nao eh publico faz-se necessario mover manualmente os fontes para o pvc vol-sei-fontes"
	@echo "====================================================================================================================="
.PHONY: kubernetes_apply
kubernetes_apply: ## Aplicar receitas no cluster kubernetes
	cd orquestrators/rancher-kubernetes/topublish/; \
	kubectl create namespace ${KUBERNETES_NAMESPACE}; \
	kubectl --insecure-skip-tls-verify apply -f registry.yaml; \
	kubectl --insecure-skip-tls-verify apply -f configmaps.yaml; \
	kubectl --insecure-skip-tls-verify apply -f secrets.yaml; \
	kubectl --insecure-skip-tls-verify apply -f pvc.yaml; \
	kubectl --insecure-skip-tls-verify apply -f jobs.yaml; \
	kubectl --insecure-skip-tls-verify apply -f statefullsets.yaml; \
	kubectl --insecure-skip-tls-verify apply -f deploys-svc.yaml; \
	kubectl --insecure-skip-tls-verify apply -f ingress.yaml;

.PHONY: kubernetes_delete
kubernetes_delete: ## Deletar receitas do cluster kubernetes
	cd orquestrators/rancher-kubernetes/topublish/; \
	kubectl --insecure-skip-tls-verify  delete -f registry.yaml --wait=true --cascade='foreground'; \
	kubectl --insecure-skip-tls-verify  delete -f ingress.yaml --wait=true --cascade='foreground'; \
	kubectl --insecure-skip-tls-verify  delete -f deploys-svc.yaml --wait=true --cascade='foreground'; \
	kubectl --insecure-skip-tls-verify  delete -f statefullsets.yaml --wait=true --cascade='foreground'; \
	kubectl --insecure-skip-tls-verify  delete -f jobs.yaml --wait=true --cascade='foreground'; \
	kubectl --insecure-skip-tls-verify  delete -f configmaps.yaml --wait=true --cascade='foreground'; \
	kubectl --insecure-skip-tls-verify  delete -f secrets.yaml --wait=true --cascade='foreground'; \
	kubectl --insecure-skip-tls-verify  delete -f pvc.yaml --wait=true --cascade='foreground'; \
	kubectl delete namespace ${KUBERNETES_NAMESPACE};

.PHONY: kubernetes_check
kubernetes_check: ## Verifica se determinado deploy ja esta pronto para uso no cluster
    
	kubectl --insecure-skip-tls-verify wait deployment $(KUBE_DEPLOY_NAME) --for condition="Available=True" --namespace=${KUBERNETES_NAMESPACE} --timeout=180s;


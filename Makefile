# Copyright (c) 2022-2023 AccelByte Inc. All Rights Reserved.
# This is licensed software from AccelByte Inc, for limitations
# and restrictions contact your company contract manager.

SHELL := /bin/bash

IMAGE_NAME := $(shell basename "$$(pwd)")-app
DOTNETVER := 6.0.302
BUILDER := grpc-plugin-server-builder

.PHONY: build image imagex test

build:
	docker run --rm -u $$(id -u):$$(id -g) -v $$(pwd):/data/ -w /data/src -e HOME="/data" -e DOTNET_CLI_HOME="/data" mcr.microsoft.com/dotnet/sdk:$(DOTNETVER) \
			dotnet build

image:
	docker build -t ${IMAGE_NAME} .

imagex:
	docker buildx inspect ${IMAGE_NAME}-builder \
			|| docker buildx create --name ${IMAGE_NAME}-builder --use 
	docker buildx build -t ${IMAGE_NAME} --platform linux/arm64,linux/amd64 .
	docker buildx build -t ${IMAGE_NAME} --load .
	#docker buildx rm ${IMAGE_NAME}-builder

imagex_push:
	@test -n "$(IMAGE_TAG)" || (echo "IMAGE_TAG is not set (e.g. 'v0.1.0', 'latest')"; exit 1)
	@test -n "$(REPO_URL)" || (echo "REPO_URL is not set"; exit 1)
	docker buildx inspect $(BUILDER) || docker buildx create --name $(BUILDER) --use
	docker buildx build -t ${REPO_URL}:${IMAGE_TAG} --platform linux/arm64,linux/amd64 --push .
	docker buildx rm --keep-state $(BUILDER)

test:
	@test -n "$(AB_CLIENT_ID)" || (echo "AB_CLIENT_ID is not set"; exit 1)
	@test -n "$(AB_CLIENT_SECRET)" || (echo "AB_CLIENT_SECRET is not set"; exit 1)
	@test -n "$(AB_BASE_URL)" || (echo "AB_BASE_URL is not set"; exit 1)
	@test -n "$(AB_NAMESPACE)" || (echo "AB_NAMESPACE is not set"; exit 1)
	docker run --rm -u $$(id -u):$$(id -g) -v $$(pwd):/data/ -w /data/src -e HOME="/data" -e DOTNET_CLI_HOME="/data" \
		-e AB_CLIENT_ID=$(AB_CLIENT_ID) \
		-e AB_BASE_URL=$(AB_BASE_URL) \
		-e AB_CLIENT_SECRET=$(AB_CLIENT_SECRET) \
		-e AB_NAMESPACE=$(AB_NAMESPACE) \
		mcr.microsoft.com/dotnet/sdk:$(DOTNETVER) \
		dotnet test

# Copyright (c) 2022-2024 AccelByte Inc. All Rights Reserved.
# This is licensed software from AccelByte Inc, for limitations
# and restrictions contact your company contract manager.

SHELL := /bin/bash

IMAGE_NAME := $(shell basename "$$(pwd)")-app
BUILDER := extend-builder

DOTNETVER := 6.0-jammy

APP_PATH := AccelByte.PluginArch.EventHandler.Demo.Server

TEST_SAMPLE_CONTAINER_NAME := sample-event-handler-test

.PHONY: test

build:
	docker run --rm -u $$(id -u):$$(id -g) \
		-v $$(pwd):/data/ \
		-e HOME="/data/.cache" -e DOTNET_CLI_HOME="/data/.cache" \
		mcr.microsoft.com/dotnet/sdk:$(DOTNETVER) \
		sh -c "mkdir -p /data/.tmp && cp -r /data/src /data/.tmp/src && cd /data/.tmp/src && dotnet build && mkdir -p /data/.output && cp -r /data/.tmp/src/$(APP_PATH)/bin/* /data/.output/ && rm -rf /data/.tmp"

image:
	docker build -t ${IMAGE_NAME} .

imagex:
	docker buildx inspect ${IMAGE_NAME}-builder \
			|| docker buildx create --name ${IMAGE_NAME}-builder --use 
	docker buildx build -t ${IMAGE_NAME} --platform linux/amd64 .
	docker buildx build -t ${IMAGE_NAME} --load .
	#docker buildx rm ${IMAGE_NAME}-builder

imagex_push:
	@test -n "$(IMAGE_TAG)" || (echo "IMAGE_TAG is not set (e.g. 'v0.1.0', 'latest')"; exit 1)
	@test -n "$(REPO_URL)" || (echo "REPO_URL is not set"; exit 1)
	docker buildx inspect $(BUILDER) || docker buildx create --name $(BUILDER) --use
	docker buildx build -t ${REPO_URL}:${IMAGE_TAG} --platform linux/amd64 --push .
	docker buildx rm --keep-state $(BUILDER)
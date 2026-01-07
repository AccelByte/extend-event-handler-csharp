# Copyright (c) 2025 AccelByte Inc. All Rights Reserved.
# This is licensed software from AccelByte Inc, for limitations
# and restrictions contact your company contract manager.

SHELL := /bin/bash

PROJECT_NAME := $(shell basename "$$(pwd)")
DOTNET_IMAGE := mcr.microsoft.com/dotnet/sdk:8.0-jammy

IS_INSIDE_DEVCONTAINER := $(REMOTE_CONTAINERS)
BUILD_CACHE_VOLUME := $(shell echo '$(PROJECT_NAME)' | sed 's/[^a-zA-Z0-9_-]//g')-build-cache

.PHONY: build

build: prepare_build_cache
ifneq ($(IS_INSIDE_DEVCONTAINER),true)
	docker run -t --rm -u $$(id -u):$$(id -g) \
			-e HOME="/tmp/build-cache/dotnet/cache" \
			-e DOTNET_CLI_HOME="/tmp/build-cache/dotnet/cache" \
			-e DOTNET_SKIP_WORKLOAD_INTEGRITY_CHECK=1 \
			-v $$(pwd):/data \
			-v $(BUILD_CACHE_VOLUME):/tmp/build-cache \
			-w /data/src \
			${DOTNET_IMAGE} \
			dotnet build
else
	cd src && dotnet build
endif

prepare_build_cache:
ifneq ($(IS_INSIDE_DEVCONTAINER),true)
	docker run -t --rm \
			-v $(BUILD_CACHE_VOLUME):/tmp/build-cache \
			busybox:1.37.0 \
			chown $$(id -u):$$(id -g) /tmp/build-cache		# Fix /tmp/build-cache folder owned by root
endif
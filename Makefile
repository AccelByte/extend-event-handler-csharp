# Copyright (c) 2022-2025 AccelByte Inc. All Rights Reserved.
# This is licensed software from AccelByte Inc, for limitations
# and restrictions contact your company contract manager.

SHELL := /bin/bash

DOTNETVER := 6.0-jammy
APP_PATH := AccelByte.PluginArch.EventHandler.Demo.Server

.PHONY: build

build:
	docker run --rm -u $$(id -u):$$(id -g) \
		-v $$(pwd):/data/ \
		-e HOME="/data/.cache" -e DOTNET_CLI_HOME="/data/.cache" \
		mcr.microsoft.com/dotnet/sdk:$(DOTNETVER) \
		sh -c "mkdir -p /data/.tmp && cp -r /data/src /data/.tmp/src && cd /data/.tmp/src && dotnet build && mkdir -p /data/.output && cp -r /data/.tmp/src/$(APP_PATH)/bin/* /data/.output/ && rm -rf /data/.tmp"
# Copyright (c) 2025 AccelByte Inc. All Rights Reserved.
# This is licensed software from AccelByte Inc, for limitations
# and restrictions contact your company contract manager.

# ----------------------------------------
# Stage 1: gRPC Server Builder
# ----------------------------------------
FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:8.0-alpine3.22 AS grpc-server-builder
ARG TARGETARCH

RUN apk update && apk add --no-cache gcompat

# Set working directory.
WORKDIR /project

# Copy project file and restore dependencies.
COPY src/AccelByte.PluginArch.EventHandler.Demo.Server/*.csproj .
RUN ([ "$TARGETARCH" = "amd64" ] && echo "linux-musl-x64" || echo "linux-musl-$TARGETARCH") > /tmp/dotnet-rid
RUN dotnet restore -r $(cat /tmp/dotnet-rid)

# Copy application code.
COPY src/AccelByte.PluginArch.EventHandler.Demo.Server/ .

# Build and publish application.
RUN dotnet publish -c Release -r $(cat /tmp/dotnet-rid) --no-restore -o /build/

# ----------------------------------------
# Stage 2: Runtime Container
# ----------------------------------------
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine3.22

# Set working directory.
WORKDIR /app

# Copy server build from stage 1.
COPY --from=grpc-server-builder /build/ .

# Plugin Arch gRPC Server Port.
EXPOSE 6565

# Prometheus /metrics Web Server Port.
EXPOSE 8080
CMD [ "/app/AccelByte.PluginArch.EventHandler.Demo.Server" ]

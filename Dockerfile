FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:8.0 as builder
# FROM mcr.microsoft.com/dotnet/sdk:6.0.302 as builder
ARG PROJECT_PATH=src/AccelByte.PluginArch.EventHandler.Demo.Server
ARG TARGETARCH
WORKDIR /build
COPY $PROJECT_PATH/*.csproj ./
RUN dotnet restore -a $TARGETARCH
COPY $PROJECT_PATH ./
RUN dotnet publish -a $TARGETARCH --no-restore -c Release -o output

FROM --platform=$TARGETPLATFORM mcr.microsoft.com/dotnet/sdk:6.0.302
# FROM mcr.microsoft.com/dotnet/sdk:6.0.302
WORKDIR /app
COPY --from=builder /build/output/* ./
RUN chmod +x /app/AccelByte.PluginArch.EventHandler.Demo.Server
# Plugin arch gRPC server port
EXPOSE 6565
# Prometheus /metrics web server port
EXPOSE 8080
ENTRYPOINT ["/app/AccelByte.PluginArch.EventHandler.Demo.Server"]

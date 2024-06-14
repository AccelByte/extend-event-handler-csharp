FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:6.0-alpine3.19 as builder
RUN apk update && apk add --no-cache gcompat
WORKDIR /build
COPY src/AccelByte.PluginArch.EventHandler.Demo.Server/*.csproj .
RUN dotnet restore -r linux-musl-x64
COPY src/AccelByte.PluginArch.EventHandler.Demo.Server/ .
RUN dotnet publish -c Release -r linux-musl-x64 -o /output


FROM mcr.microsoft.com/dotnet/aspnet:6.0-alpine3.19
WORKDIR /app
COPY --from=builder /output/ .
# gRPC server port, Prometheus /metrics port
EXPOSE 6565 8080
ENTRYPOINT ["/app/AccelByte.PluginArch.EventHandler.Demo.Server"]

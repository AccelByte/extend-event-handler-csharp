# gRPC server builder

FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:6.0-alpine3.19 AS grpc-server-builder
ARG TARGETARCH
RUN apk update && apk add --no-cache gcompat
WORKDIR /project
COPY src/AccelByte.PluginArch.EventHandler.Demo.Server/*.csproj .
RUN ([ "$TARGETARCH" = "amd64" ] && echo "linux-musl-x64" || echo "linux-musl-$TARGETARCH") > /tmp/dotnet-rid
RUN dotnet restore -r $(cat /tmp/dotnet-rid)
COPY src/AccelByte.PluginArch.EventHandler.Demo.Server/ .
RUN dotnet publish -c Release -r $(cat /tmp/dotnet-rid) --no-restore -o /build/

# Extend Event Handler app

FROM mcr.microsoft.com/dotnet/aspnet:6.0-alpine3.19
WORKDIR /app
COPY --from=grpc-server-builder /build/ .
# gRPC server port and /metrics HTTP port
EXPOSE 6565 8080
CMD [ "/app/AccelByte.PluginArch.EventHandler.Demo.Server" ]

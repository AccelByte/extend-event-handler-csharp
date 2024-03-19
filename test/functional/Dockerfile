FROM mcr.microsoft.com/dotnet/sdk:6.0-alpine3.19
WORKDIR /workspace
RUN apk --no-cache add bash curl docker-cli-buildx git jq make gcompat \
                && apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing grpcurl

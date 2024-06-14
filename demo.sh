#!/usr/bin/env bash

set -e
set -o pipefail
#set -x

test -n "$AB_CLIENT_ID" || (echo "AB_CLIENT_ID is not set"; exit 1)
test -n "$AB_CLIENT_SECRET" || (echo "AB_CLIENT_SECRET is not set"; exit 1)
test -n "$AB_NAMESPACE" || (echo "AB_NAMESPACE is not set"; exit 1)

RANDOM_SUFFIX="$(echo $RANDOM | sha1sum | head -c 6)"

DEMO_PREFIX="eh_demo_cs_$RANDOM_SUFFIX"

get_code_verifier() 
{
  echo $RANDOM | sha256sum | cut -d ' ' -f 1   # For testing only: In reality, it needs to be secure random
}

get_code_challenge()
{
  echo -n "$1" | sha256sum | xxd -r -p | base64 | tr -d '\n' | sed -e 's/+/-/g' -e 's/\//\_/g' -e 's/=//g'
}

api_curl()
{
  curl -s -D api_curl_http_header.out -o api_curl_http_response.out -w '%{http_code}' "$@" > api_curl_http_code.out
  echo >> api_curl_http_response.out
  cat api_curl_http_response.out
}

function clean_up()
{
  echo Deleting player ...

  api_curl -X DELETE "${AB_BASE_URL}/iam/v3/admin/namespaces/$AB_NAMESPACE/users/$USER_ID/information" \
      -H "Authorization: Bearer $ACCESS_TOKEN" >/dev/null       # Ignore delete error
}

echo Logging in client ...

ACCESS_TOKEN="$(api_curl ${AB_BASE_URL}/iam/v3/oauth/token \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -u "$AB_CLIENT_ID:$AB_CLIENT_SECRET" \
    -d "grant_type=client_credentials" | jq --raw-output .access_token)"

if [ "$ACCESS_TOKEN" == "null" ]; then
    cat api_curl_http_response.out
    exit 1
fi

trap clean_up EXIT

echo Creating player ${DEMO_PREFIX}_player@test.com ...

USER_ID="$(api_curl "${AB_BASE_URL}/iam/v4/public/namespaces/$AB_NAMESPACE/users" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"authType\":\"EMAILPASSWD\",\"country\":\"ID\",\"dateOfBirth\":\"1995-01-10\",\"displayName\":\"Event Handler Test Player $RANDOM_SUFFIX\",\"uniqueDisplayName\":\"Cloudsave gRPC Player $RANDOM_SUFFIX\",\"emailAddress\":\"${DEMO_PREFIX}_player@test.com\",\"password\":\"GFPPlmdb2-\",\"username\":\"${DEMO_PREFIX}_player\"}" | jq --raw-output .userId)"

if [ "$USER_ID" == "null" ]; then
    cat api_curl_http_response.out
    exit 1
fi

if [ -n "$GRPC_SERVER_URL" ]; then
    grpcurl -plaintext \
            -d "{\"payload\":{\"userAccount\":{\"userId\":\"string\",\"emailAddress\":\"string\",\"country\":\"string\",\"namespace\":\"string\"},\"userAuthentication\":{\"platformId\":\"string\",\"refresh\":true}},\"id\":\"string\",\"version\":0,\"name\":\"string\",\"namespace\":\"$AB_NAMESPACE\",\"parentNamespace\":\"string\",\"timestamp\":\"2019-08-24T14:15:22Z\",\"clientId\":\"string\",\"userId\":\"$USER_ID\",\"traceId\":\"string\",\"sessionId\":\"string\"}" \
            localhost:6565 \
            accelbyte.iam.account.v1.UserAuthenticationUserLoggedInService/OnMessage
else
    echo Logging in player ${DEMO_PREFIX}_player@test.com ...

    CODE_VERIFIER="$(get_code_verifier)"

    api_curl "${AB_BASE_URL}/iam/v3/oauth/authorize?scope=commerce+account+social+publishing+analytics&response_type=code&code_challenge_method=S256&code_challenge=$(get_code_challenge "$CODE_VERIFIER")&client_id=$AB_CLIENT_ID"

    if [ "$(cat api_curl_http_code.out)" -ge "400" ]; then
        exit 1
    fi

    REQUEST_ID="$(cat api_curl_http_header.out | grep -o 'request_id=[a-f0-9]\+' | cut -d= -f2)"

    api_curl ${AB_BASE_URL}/iam/v3/authenticate \
            -H 'Content-Type: application/x-www-form-urlencoded' \
            -d "password=GFPPlmdb2-&user_name=${DEMO_PREFIX}_player@test.com&request_id=$REQUEST_ID&client_id=$AB_CLIENT_ID"

    if [ "$(cat api_curl_http_code.out)" -ge "400" ]; then
        exit 1
    fi

    CODE="$(cat api_curl_http_header.out | grep -o 'code=[a-f0-9]\+' | cut -d= -f2)"

    PLAYER_ACCESS_TOKEN="$(api_curl ${AB_BASE_URL}/iam/v3/oauth/token \
            -H 'Content-Type: application/x-www-form-urlencoded' -u "$AB_CLIENT_ID:$AB_CLIENT_SECRET" \
            -d "code=$CODE&grant_type=authorization_code&client_id=$AB_CLIENT_ID&code_verifier=$CODE_VERIFIER" | jq --raw-output .access_token)"

    if [ "$PLAYER_ACCESS_TOKEN" == "null" ]; then
        cat http_response.out
        exit 1
    fi
fi

echo  "# Waiting until item is granted to user ..."

sleep 120s

ENTITLEMENTS_DATA=$(api_curl "${AB_BASE_URL}/platform/admin/namespaces/$AB_NAMESPACE/users/$USER_ID/entitlements?activeOnly=false&limit=20&offset=0" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H 'Content-Type: application/json')

if echo "$ENTITLEMENTS_DATA" | jq '.data[].itemId' | grep -q "$ITEM_ID_TO_GRANT"; then
    echo Item id $ITEM_ID_TO_GRANT is granted to user id $USER_ID
else
    echo Item id $ITEM_ID_TO_GRANT is NOT granted to user id $USER_ID
    exit 1
fi

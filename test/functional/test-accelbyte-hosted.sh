#!/usr/bin/env bash

APP_NAME=Event-Handler

get_code_verifier() 
{
  echo $RANDOM | sha256sum | cut -d ' ' -f 1   # For testing only: In reality, it needs to be secure random
}

get_code_challenge()
{
  echo -n "$1" | sha256sum | xxd -r -p | base64 -w 0 | sed -e 's/+/-/g' -e 's/\//\_/g' -e 's/=//g'
}

function api_curl()
{
  HTTP_CODE=$(curl -s -o http_response.out -w '%{http_code}' "$@")
  echo $HTTP_CODE > http_code.out
  cat http_response.out
  echo
  echo $HTTP_CODE | grep -q '\(200\|201\|204\|302\)' || return 123
}

function clean_up()
{
    echo Deleting published store ...

    api_curl -X DELETE "${AB_BASE_URL}/platform/admin/namespaces/$AB_NAMESPACE/stores/published" \
        -H "Authorization: Bearer $ACCESS_TOKEN" || true      # Ignore delete error

    echo Deleting draft store ...

    api_curl -X DELETE "${AB_BASE_URL}/platform/admin/namespaces/$AB_NAMESPACE/stores/$STORE_ID" \
        -H "Authorization: Bearer $ACCESS_TOKEN" || true      # Ignore delete error

    echo Deleting Extend app ...

    api_curl -X DELETE "${AB_BASE_URL}/csm/v1/admin/namespaces/$AB_NAMESPACE/apps/$APP_NAME" \
        -H "Authorization: Bearer $ACCESS_TOKEN" || true      # Ignore delete error

    echo '# Delete OAuth client'

    OAUTH_CLIENT_LIST=$(api_curl "${AB_BASE_URL}/iam/v3/admin/namespaces/$AB_NAMESPACE/clients?clientName=extend-$APP_NAME&limit=20" \
        -H "Authorization: Bearer $ACCESS_TOKEN")

    OAUTH_CLIENT_LIST_COUNT=$(echo "$OAUTH_CLIENT_LIST" | jq '.data | length')

    if [ "$OAUTH_CLIENT_LIST_COUNT" -eq 0 ] || [ "$OAUTH_CLIENT_LIST_COUNT" -gt 1 ]; then
        echo "Failed to to clean up OAuth client (name: extend-$APP_NAME)"
        exit 1
    fi

    OAUTH_CLIENT_ID="$(echo "$OAUTH_CLIENT_LIST" | jq -r '.data[0].clientId')"

    api_curl "${AB_BASE_URL}/iam/v3/admin/namespaces/$AB_NAMESPACE/clients/$OAUTH_CLIENT_ID" \
        -X 'DELETE' \
        -H "Authorization: Bearer $ACCESS_TOKEN"
}

echo '# Downloading extend-helper-cli'

curl -sf https://api.github.com/repos/AccelByte/extend-helper-cli/releases/latest \
        | grep "/extend-helper-cli-linux" | cut -d : -f 2,3 | tr -d \" \
        | curl -sL --output extend-helper-cli $(cat)
chmod +x ./extend-helper-cli

echo '# Preparing test environment (stage 1)'

echo 'Logging in user ...'

CODE_VERIFIER="$(get_code_verifier)"
CODE_CHALLENGE="$(get_code_challenge "$CODE_VERIFIER")"
REQUEST_ID="$(curl -sf -D - "${AB_BASE_URL}/iam/v3/oauth/authorize?scope=commerce+account+social+publishing+analytics&response_type=code&code_challenge_method=S256&code_challenge=$CODE_CHALLENGE&client_id=$AB_CLIENT_ID" | grep -o 'request_id=[a-f0-9]\+' | cut -d= -f2)"
CODE="$(curl -sf -D - ${AB_BASE_URL}/iam/v3/authenticate -H 'Content-Type: application/x-www-form-urlencoded' -d "password=$AB_PASSWORD&user_name=$AB_USERNAME&request_id=$REQUEST_ID&client_id=$AB_CLIENT_ID" | grep -o 'code=[a-f0-9]\+' | cut -d= -f2)"
ACCESS_TOKEN="$(curl -sf ${AB_BASE_URL}/iam/v3/oauth/token -H 'Content-Type: application/x-www-form-urlencoded' -u "$AB_CLIENT_ID:$AB_CLIENT_SECRET" -d "code=$CODE&grant_type=authorization_code&client_id=$AB_CLIENT_ID&code_verifier=$CODE_VERIFIER" | jq --raw-output .access_token)"

echo 'Creating Extend app ...'

api_curl "${AB_BASE_URL}/csm/v1/admin/namespaces/${AB_NAMESPACE}/apps/$APP_NAME" \
  -X 'PUT' \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H 'content-type: application/json' \
  --data-raw '{"scenario":"event-handler","description":"Extend integration test"}'

if [ "$ACCESS_TOKEN" == "null" ]; then
    cat http_response.out
    exit 1
fi

trap clean_up EXIT

for _ in {1..60}; do
    STATUS=$(api_curl "${AB_BASE_URL}/csm/v1/admin/namespaces/${AB_NAMESPACE}/apps?limit=500&offset=0" \
            -H "Authorization: Bearer $ACCESS_TOKEN" \
            -H 'content-type: application/json' \
            --data-raw "{\"appNames\":[\"${APP_NAME}\"],\"statuses\":[],\"scenario\":\"event-handler\"}" \
            | jq -r '.data[0].status')
    if [ "$STATUS" = "S" ]; then
        break
    fi
    echo "Waiting until Extend app created (status: $STATUS)"
    sleep 10
done

if ! [ "$STATUS" = "S" ]; then
    echo "Failed to create Extend app (status: $STATUS)"
    exit 1
fi

echo '# Build and push Extend app'

APP_DETAILS=$(api_curl "${AB_BASE_URL}/csm/v1/admin/namespaces/${AB_NAMESPACE}/apps/$APP_NAME" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

APP_REPO_URL=$(echo "$APP_DETAILS" | jq -r '.appRepoUrl')
APP_REPO_HOST=$(echo "$APP_REPO_URL" | cut -d/ -f1)

./extend-helper-cli dockerlogin --namespace $AB_NAMESPACE --app $APP_NAME -p | docker login -u AWS --password-stdin $APP_REPO_HOST

#make build
make imagex_push REPO_URL=$APP_REPO_URL IMAGE_TAG=v0.0.1

echo '# Preparing test environment (stage 2)'

echo Checking currency USD ...

CURRENCIES_DATA=$(api_curl "https://demo.accelbyte.io/platform/admin/namespaces/$AB_NAMESPACE/currencies" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H 'Content-Type: application/json')

if ! echo "$CURRENCIES_DATA" | jq .[].currencyCode | grep -q '"USD"'; then
    echo Creating currency USD ...

    curl "https://demo.accelbyte.io/platform/admin/namespaces/$AB_NAMESPACE/currencies" \
            -H "Authorization: Bearer $ACCESS_TOKEN" \
            -H 'Content-Type: application/json' \
            -d '{"currencyCode":"USD","localizationDescriptions":{"en":"US Dollars"},"currencySymbol":"US$","currencyType":"REAL","decimals":2}'
fi

echo Creating event handler store ...

STORE_ID="$(api_curl "${AB_BASE_URL}/platform/admin/namespaces/$AB_NAMESPACE/stores" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"title\":\"event handler store\",\"supportedLanguages\":[],\"supportedRegions\":[],\"defaultRegion\":\"US\",\"defaultLanguage\":\"en\"}" | jq --raw-output .storeId)"

if [ "$STORE_ID" == "null" ]; then
    cat http_response.out
    exit 1
fi

echo Creating event handler store category ...

api_curl "${AB_BASE_URL}/platform/admin/namespaces/$AB_NAMESPACE/categories?storeId=$STORE_ID" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H 'Content-Type: application/json' \
    --data-raw '{"categoryPath":"/eventhandlercategory","localizationDisplayNames":{"en":"eventhandlercategory"}}'

if ! cat http_code.out | grep -q '\(200\|201\|204\|302\)'; then
    cat http_response.out
    exit 1
fi

echo Creating event handler store item ...

ITEM_ID="$(api_curl "${AB_BASE_URL}/platform/admin/namespaces/$AB_NAMESPACE/items?storeId=$STORE_ID" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"entitlementType\":\"DURABLE\",\"maxCount\":-1,\"maxCountPerUser\":-1,\"useCount\":1,\"baseAppId\":\"\",\"itemType\":\"INGAMEITEM\",\"name\":\"eventhandleritem\",\"listable\":true,\"purchasable\":true,\"localizations\":{\"en\":{\"title\":\"eventhandleritem\"}},\"regionData\":{\"US\":[{\"price\":1,\"currencyNamespace\":\"$AB_NAMESPACE\",\"currencyCode\":\"USD\",\"purchaseAt\":\"2024-01-22T04:32:26.204Z\",\"discountPurchaseAt\":\"2024-01-22T04:32:26.204Z\"}]},\"sku\":\"EVT12345\",\"flexible\":false,\"sectionExclusive\":false,\"status\":\"ACTIVE\",\"categoryPath\":\"/eventhandlercategory\",\"features\":[],\"sellable\":false}" | jq --raw-output .itemId)"

if [ "$ITEM_ID" == "null" ]; then
    cat http_response.out
    exit 1
fi

export ITEM_ID_TO_GRANT=$ITEM_ID

echo Publishing event handler store ...

api_curl "${AB_BASE_URL}/platform/admin/namespaces/$AB_NAMESPACE/stores" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H 'Content-Type: application/json'     # Check before publishing store

api_curl -X PUT "${AB_BASE_URL}/platform/admin/namespaces/$AB_NAMESPACE/stores/$STORE_ID/catalogChanges/publishAll" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H 'Content-Type: application/json'

if ! cat http_code.out | grep -q '\(200\|201\|204\|302\)'; then
    cat http_response.out
    exit 1
fi

echo "Deploying Extend app ..."

SECRETS_DATA=$(api_curl "${AB_BASE_URL}/csm/v1/admin/namespaces/${AB_NAMESPACE}/apps/$APP_NAME/secrets?limit=200&offset=0" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H 'content-type: application/json')

CLIENT_ID_UUID=$(echo "$SECRETS_DATA" | jq -r '.data[] | select(.configName=="AB_CLIENT_ID") | .configId')
CLIENT_SECRET_UUID=$(echo "$SECRETS_DATA" | jq -r '.data[] | select(.configName=="AB_CLIENT_SECRET") | .configId')

api_curl -X PUT "${AB_BASE_URL}/csm/v1/admin/namespaces/${AB_NAMESPACE}/apps/$APP_NAME/secrets/$CLIENT_ID_UUID" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H 'content-type: application/json' \
        --data-raw "{\"value\":\"$AB_CLIENT_ID\"}"

if ! cat http_code.out | grep -q '\(200\|201\|204\|302\)'; then
    cat http_response.out
    exit 1
fi

api_curl -X PUT "${AB_BASE_URL}/csm/v1/admin/namespaces/${AB_NAMESPACE}/apps/$APP_NAME/secrets/$CLIENT_SECRET_UUID" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H 'content-type: application/json' \
        --data-raw "{\"value\":\"$AB_CLIENT_SECRET\"}"

if ! cat http_code.out | grep -q '\(200\|201\|204\|302\)'; then
    cat http_response.out
    exit 1
fi

api_curl "${AB_BASE_URL}/csm/v1/admin/namespaces/${AB_NAMESPACE}/apps/$APP_NAME/variables" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H 'content-type: application/json' \
        --data-raw "{\"configName\":\"ITEM_ID_TO_GRANT\",\"value\":\"${ITEM_ID_TO_GRANT}\",\"source\":\"plaintext\",\"description\":\"\"}"

if ! cat http_code.out | grep -q '\(200\|201\|204\|302\)'; then
    cat http_response.out
    exit 1
fi

api_curl "${AB_BASE_URL}/csm/v1/admin/namespaces/${AB_NAMESPACE}/apps/$APP_NAME/deployments" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H 'content-type: application/json' \
        --data-raw '{"imageTag":"v0.0.1","description":""}'

if ! cat http_code.out | grep -q '\(200\|201\|204\|302\)'; then
    cat http_response.out
    exit 1
fi

for _ in {1..60}; do
    STATUS=$(api_curl "${AB_BASE_URL}/csm/v1/admin/namespaces/${AB_NAMESPACE}/apps?limit=500&offset=0" \
            -H "Authorization: Bearer $ACCESS_TOKEN" \
            -H 'content-type: application/json' \
            --data-raw "{\"appNames\":[\"${APP_NAME}\"],\"statuses\":[],\"scenario\":\"event-handler\"}" \
            | jq -r '.data[0].app_release_status')
    if [ "$STATUS" = "R" ]; then
        break
    fi
    echo "Waiting until Extend app deployed (status: $STATUS)"
    sleep 10
done

if ! [ "$STATUS" = "R" ]; then
    echo "Failed to deploy Extend app (status: $STATUS)"
    exit 1
fi

echo  "# Waiting until Extend App is fully running ..."

sleep 180s

echo '# Testing Extend app using demo script'

unset GRPC_SERVER_URL

bash demo.sh

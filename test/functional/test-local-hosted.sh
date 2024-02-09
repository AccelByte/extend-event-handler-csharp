#!/usr/bin/env bash

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

  kill -9 $GRPC_SERVER_PID
}

trap clean_up EXIT

echo '# Preparing test environment'

echo Logging in client ...

ACCESS_TOKEN="$(api_curl ${AB_BASE_URL}/iam/v3/oauth/token \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -u "$AB_CLIENT_ID:$AB_CLIENT_SECRET" \
    -d "grant_type=client_credentials" | jq --raw-output .access_token)"

if [ "$ACCESS_TOKEN" == "null" ]; then
    cat http_response.out
    exit 1
fi

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

echo '# Build and run Extend app locally'

(cd src/AccelByte.PluginArch.EventHandler.Demo.Server && dotnet run) & GRPC_SERVER_PID=$!

(for _ in {1..12}; do bash -c "timeout 1 echo > /dev/tcp/127.0.0.1/8080" 2>/dev/null && exit 0 || sleep 5s; done; exit 1)

if [ $? -ne 0 ]; then
  echo "Failed to run Extend app locally"
  exit 1
fi

echo '# Testing Extend app using demo script'

export GRPC_SERVER_URL=localhost:6565

bash demo.sh

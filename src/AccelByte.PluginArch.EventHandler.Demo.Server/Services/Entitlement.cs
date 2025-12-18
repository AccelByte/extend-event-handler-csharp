// Copyright (c) 2023-2025 AccelByte Inc. All Rights Reserved.
// This is licensed software from AccelByte Inc, for limitations
// and restrictions contact your company contract manager.

using AccelByte.Sdk.Api.Platform.Model;
using AccelByte.Sdk.Api;
using AccelByte.Sdk.Core;

namespace AccelByte.PluginArch.EventHandler.Demo.Server.Services
{
    public static class Entitlement
    {
        public static void grantEntitlement(
            AccelByteSDK sdk,
            string @namespace,
            string userId,
            string itemId)
        {
            var fulfillmentRequest = new FulfillmentRequest()
            {
                ItemId = itemId,
                Quantity = 1,
                Source = FulfillmentRequestSource.REWARD
            };
            
            sdk.Platform.Fulfillment.FulfillItemOp
                .Execute(fulfillmentRequest, @namespace, userId);
        }
    }
}

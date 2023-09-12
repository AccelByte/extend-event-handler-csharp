// Copyright (c) 2023 AccelByte Inc. All Rights Reserved.
// This is licensed software from AccelByte Inc, for limitations
// and restrictions contact your company contract manager.

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Configuration;

using Grpc.Core;
using AccelByte.IAM.Account;
using Google.Protobuf.WellKnownTypes;

using AccelByte.Sdk.Api.Platform.Model;
using AccelByte.Sdk.Api;

namespace AccelByte.PluginArch.EventHandler.Demo.Server.Services
{
    public class UserLoggedInService : UserAuthenticationUserLoggedInService.UserAuthenticationUserLoggedInServiceBase
    {
        private readonly ILogger<UserLoggedInService> _Logger;

        private readonly IAccelByteServiceProvider _ABProvider;

        public UserLoggedInService(
            ILogger<UserLoggedInService> logger,
            IAccelByteServiceProvider abProvider)
        {
            _Logger = logger;
            _ABProvider = abProvider;
        }

        public override Task<Empty> OnMessage(UserLoggedIn request, ServerCallContext context)
        {
            string targetNamespace = _ABProvider.Sdk.Namespace;
            _Logger.LogInformation($"NS Target: {targetNamespace}, Request: {request.Namespace}");
            _Logger.LogInformation($"Log in UserId: {request.UserId}");

            //if user doesn't login for the same namespace as the plugin
            if (request.Namespace != targetNamespace)
                return Task.FromResult(new Empty());
            
            var newEntitlement = _ABProvider.Sdk.Platform.Entitlement.GrantUserEntitlementOp
                .SetBody(new List<EntitlementGrant>()
                {
                    new EntitlementGrant()
                    {
                        ItemId = _ABProvider.ItemIdToGrant,
                        Quantity = 1,
                        Source = EntitlementGrantSource.REWARD,
                        ItemNamespace = targetNamespace,
                    }
                })
                .Execute(targetNamespace, request.UserId);
            if (newEntitlement != null)
            {
                foreach (var entitlementItem in newEntitlement)
                    _Logger.LogInformation($"EntitlementId: {entitlementItem.Id!}");
            }

            return Task.FromResult(new Empty());
        }
    }
}

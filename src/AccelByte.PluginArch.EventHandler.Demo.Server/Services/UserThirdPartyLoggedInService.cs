// Copyright (c) 2023-2025 AccelByte Inc. All Rights Reserved.
// This is licensed software from AccelByte Inc, for limitations
// and restrictions contact your company contract manager.

using System.Threading.Tasks;

using Microsoft.Extensions.Logging;

using Grpc.Core;
using AccelByte.IAM.Account;
using Google.Protobuf.WellKnownTypes;

namespace AccelByte.PluginArch.EventHandler.Demo.Server.Services
{
    public class UserThirdPartyLoggedInService : UserAuthenticationUserThirdPartyLoggedInService.UserAuthenticationUserThirdPartyLoggedInServiceBase
    {
        private readonly IAccelByteServiceProvider _ABProvider;
        private readonly ILogger<UserThirdPartyLoggedInService> _Logger;

        public UserThirdPartyLoggedInService(
            ILogger<UserThirdPartyLoggedInService> logger,
            IAccelByteServiceProvider abProvider)
        {
            _ABProvider = abProvider;
            _Logger = logger;
        }

        public override Task<Empty> OnMessage(UserThirdPartyLoggedIn request, ServerCallContext context)
        {
            _Logger.LogInformation("Received UserThirdPartyLoggedIn event: {@Request}", request);

            Entitlement.GrantEntitlement(
                        _ABProvider.Sdk,
                        _ABProvider.Sdk.Namespace,
                        request.UserId,
                        _ABProvider.ItemIdToGrant
                    );
                    
            return Task.FromResult(new Empty());
        }
    }
}


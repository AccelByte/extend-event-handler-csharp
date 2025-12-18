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
    public class UserLoggedInService : UserAuthenticationUserLoggedInService.UserAuthenticationUserLoggedInServiceBase
    {
        private readonly IAccelByteServiceProvider _ABProvider;
        private readonly ILogger<UserLoggedInService> _Logger;

        public UserLoggedInService(
            ILogger<UserLoggedInService> logger,
            IAccelByteServiceProvider abProvider)
        {
            _ABProvider = abProvider;
            _Logger = logger;
        }

        public override Task<Empty> OnMessage(UserLoggedIn request, ServerCallContext context)
        {
            _Logger.LogInformation("Received UserLoggedIn event: {@Request}", request);
            
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

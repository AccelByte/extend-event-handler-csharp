// Copyright (c) 2022-2023 AccelByte Inc. All Rights Reserved.
// This is licensed software from AccelByte Inc, for limitations
// and restrictions contact your company contract manager.

using System;

using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Configuration;

using AccelByte.Sdk.Core;
using AccelByte.Sdk.Feature.LocalTokenValidation;

namespace AccelByte.PluginArch.EventHandler.Demo.Server
{
    public class DefaultAccelByteServiceProvider : IAccelByteServiceProvider
    {
        private ILogger<DefaultAccelByteServiceProvider> _Logger;

        public AccelByteSDK Sdk { get; }

        public AppSettingConfigRepository Config { get; }

        public string ItemIdToGrant => Config.ItemIdToGrant;

        public DefaultAccelByteServiceProvider(IConfiguration config, ILogger<DefaultAccelByteServiceProvider> logger)
        {
            _Logger = logger;
            AppSettingConfigRepository? abConfig = config.GetSection("AccelByte").Get<AppSettingConfigRepository>();
            if (abConfig == null)
                throw new Exception("Missing AccelByte configuration section.");
            Config = abConfig;

            Sdk = AccelByteSDK.Builder
                .SetConfigRepository(Config)
                .UseDefaultCredentialRepository()
                .UseDefaultHttpClient()
                .UseDefaultTokenRepository()
                .UseLocalTokenValidator()
                .UseAutoRefreshForTokenRevocationList()
                .Build();
        }
    }
}

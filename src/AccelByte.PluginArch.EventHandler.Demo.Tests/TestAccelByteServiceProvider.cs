// Copyright (c) 2023 AccelByte Inc. All Rights Reserved.
// This is licensed software from AccelByte Inc, for limitations
// and restrictions contact your company contract manager.

using System;

using AccelByte.Sdk.Core;
using AccelByte.PluginArch.EventHandler.Demo.Server;

namespace AccelByte.PluginArch.EventHandler.Demo.Tests
{
    public class TestAccelByteServiceProvider : IAccelByteServiceProvider
    {
        public AccelByteSDK Sdk { get; }

        public AppSettingConfigRepository Config { get; }

        public string ItemIdToGrant { get; }

        public TestAccelByteServiceProvider(AccelByteSDK sdk, string itemIdToGrant)
        {
            Sdk = sdk;
            Config = new AppSettingConfigRepository();
            ItemIdToGrant = itemIdToGrant;
        }
    }
}

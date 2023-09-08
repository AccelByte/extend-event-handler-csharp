// Copyright (c) 2023 AccelByte Inc. All Rights Reserved.
// This is licensed software from AccelByte Inc, for limitations
// and restrictions contact your company contract manager.

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

using NUnit.Framework;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;

using AccelByte.IAM.Account;
using AccelByte.PluginArch.EventHandler.Demo.Server.Services;

using AccelByte.Sdk.Core;
using AccelByte.Sdk.Api;
using AccelByte.Sdk.Api.Platform.Operation;
using AccelByte.Sdk.Api.Platform.Model;
using AccelByte.Sdk.Core.Util;
using OpenTelemetry;

namespace AccelByte.PluginArch.EventHandler.Demo.Tests
{
    [TestFixture]
    public class UserLoggedInServiceTests
    {
        private ILogger<UserLoggedInService> _ServiceLogger;

        public UserLoggedInServiceTests()
        {
            ILoggerFactory loggerFactory = new NullLoggerFactory();
            _ServiceLogger = loggerFactory.CreateLogger<UserLoggedInService>();
        }

        [Test]
        public async Task UserLoggedInTest()
        {
            //THIS TEST WILL MODIFY YOUR STORES, USE IT IN TEST NAMESPACE ONLY

            string rts = Helper.GenerateRandomId(6);
            bool isDraftStoreExists = false;

            string tStoreName = $"UserLoggedIn Event Handler Demo Grpc Server {rts}";
            string tStoreDesc = $"Draft store for UserLoggedIn event handler demo grpc server [{rts}].";
            string tStoreId = "";
            string tStoreCategory = $"/sample{rts}";
            string tItemName = $"Sample Item for Event Handler Demo {rts}";
            string tItemSku = $"SKU_SAMPLE_{rts}";
            string tItemId;

            using AccelByteSDK adminSdk = AccelByteSDK.Builder
                .UseDefaultHttpClient()
                .UseDefaultConfigRepository()
                .UseDefaultTokenRepository()
                .Build();
            adminSdk.LoginClient();

            //Check whether draft store is already exists or not
            List<StoreInfo>? stores = adminSdk.Platform.Store.ListStoresOp
                .Execute(adminSdk.Namespace);
            if ((stores != null) && (stores.Count > 0))
            {
                foreach (var store in stores)
                {
                    if (store.Published! != true)
                    {
                        tStoreId = store.StoreId!;
                        isDraftStoreExists = true;
                    }
                }
            }

            if (!isDraftStoreExists)
            {
                //Create a draft store
                StoreCreate createStore = new StoreCreate()
                {
                    Title = tStoreName,
                    Description = tStoreDesc,
                    DefaultLanguage = "en",
                    DefaultRegion = "US",
                    SupportedLanguages = new List<string>() { "en" },
                    SupportedRegions = new List<string>() { "US" }
                };

                StoreInfo? cStore = adminSdk.Platform.Store.CreateStoreOp
                    .SetBody(createStore)
                    .Execute(adminSdk.Namespace);
                if (cStore == null)
                    throw new Exception("Could not create new draft store.");
                tStoreId = cStore.StoreId!;
            }

            //Create a store category
            adminSdk.Platform.Category.CreateCategoryOp
                .SetBody(new CategoryCreate()
                {
                    CategoryPath = tStoreCategory,
                    LocalizationDisplayNames = new Dictionary<string, string>() { { "en", tStoreCategory } }
                })
                .Execute(adminSdk.Namespace, tStoreId);

            //Create a sample item
            var newItem = adminSdk.Platform.Item.CreateItemOp
                .SetBody(new ItemCreate()
                {
                    Name = tItemName,
                    ItemType = ItemCreateItemType.INGAMEITEM,
                    CategoryPath = tStoreCategory,
                    EntitlementType = ItemCreateEntitlementType.CONSUMABLE,
                    SeasonType = ItemCreateSeasonType.TIER,
                    Status = ItemCreateStatus.ACTIVE,
                    Listable = true,
                    Purchasable = true,
                    Sku = tItemSku,
                    UseCount = 1,
                    Localizations = new Dictionary<string, Localization>()
                    {
                        { "en", new Localization()
                            {
                                Title = tItemName
                            }
                        }
                    },
                    RegionData = new Dictionary<string, List<RegionDataItemDTO>>()
                    {
                        { "US", new List<RegionDataItemDTO>()
                            {
                                { new RegionDataItemDTO() {
                                    CurrencyCode = "USD",
                                    CurrencyNamespace = adminSdk.Namespace,
                                    CurrencyType = RegionDataItemDTOCurrencyType.REAL,
                                    Price = 1
                                }}
                            }
                        }
                    }
                })
                .Execute(adminSdk.Namespace, tStoreId);
            if (newItem == null)
                throw new Exception("Could not create store item.");
            tItemId = newItem.ItemId!;

            //Publish only relevan store changes
            var storeChanges = adminSdk.Platform.CatalogChanges.QueryChangesOp
                .SetAction(QueryChangesAction.CREATE)
                .SetStatus(QueryChangesStatus.UNPUBLISHED)
                .SetOffset(0)
                .SetLimit(100)
                .Execute(adminSdk.Namespace, tStoreId);
            if (storeChanges == null)
                throw new Exception("Store changes response is NULL");
            if (storeChanges.Data == null)
                throw new Exception("Store changes has no data");

            foreach (var change in storeChanges.Data)
            {
                if ((change.ItemId == tItemId)
                    || (change.CategoryPath == tStoreCategory))
                {
                    adminSdk.Platform.CatalogChanges.SelectRecordOp
                        .Execute(change.ChangeId!, adminSdk.Namespace, tStoreId);
                }                
            }

            adminSdk.Platform.CatalogChanges.PublishSelectedOp
                .Execute(adminSdk.Namespace, tStoreId);

            //CREATE A PLAYER
            NewTestUser testUser = new NewTestUser(adminSdk, true);

            //LOGIN THE PLAYER
            testUser.Login();

            try
            {
                //Execute grpc function test
                var service = new UserLoggedInService(_ServiceLogger, new TestAccelByteServiceProvider(adminSdk, tItemId));
                var response = await service.OnMessage(new UserLoggedIn()
                {
                    UserId = testUser.UserId,
                    Namespace = testUser.SdkObject.Namespace
                }, new UnitTestCallContext());

                //Check whether the user have the item or not
                var ownership = adminSdk.Platform.Entitlement.ExistsAnyUserActiveEntitlementByItemIdsOp
                    .Execute(adminSdk.Namespace, testUser.UserId, new List<string>() { tItemId });
                Assert.IsNotNull(ownership);
                Assert.IsTrue(ownership!.Owned);
            }
            finally
            {
                //Logout and then delete the user.
                testUser.Logout();

                //Remove item
                adminSdk.Platform.Item.DeleteItemOp
                    .SetForce(true)
                    .Execute(tItemId, adminSdk.Namespace);

                /*
                //Remove the category
                adminSdk.Platform.Category.DeleteCategoryOp
                    .Execute(tStoreCategory, adminSdk.Namespace, tStoreId);
                */

                if (!isDraftStoreExists)
                {
                    //if draft didn't exists previously, we can remove it.
                    adminSdk.Platform.Store.DeleteStoreOp
                        .Execute(adminSdk.Namespace, tStoreId);
                }
            }  
        }
    }
}

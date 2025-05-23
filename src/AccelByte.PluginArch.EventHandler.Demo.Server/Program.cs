// Copyright (c) 2023-2025 AccelByte Inc. All Rights Reserved.
// This is licensed software from AccelByte Inc, for limitations
// and restrictions contact your company contract manager.

using System;
using System.Collections.Generic;
using System.Reflection;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Configuration;

using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using OpenTelemetry.Metrics;
using OpenTelemetry.Extensions.Propagators;

using Prometheus;
using AccelByte.PluginArch.EventHandler.Demo.Server.Services;

namespace AccelByte.PluginArch.EventHandler.Demo.Server
{
    public class Program
    {
        public static int Main(string[] args)
        {
            OpenTelemetry.Sdk.SetDefaultTextMapPropagator(new B3Propagator());

            string? appServiceName = Environment.GetEnvironmentVariable("OTEL_SERVICE_NAME");
            if (appServiceName == null)
                appServiceName = "extend-app-event-handler";
            else
                appServiceName = $"extend-app-{appServiceName.Trim().ToLower()}";

            Metrics.DefaultRegistry.SetStaticLabels(new Dictionary<string, string>()
            {
                { "application", appServiceName }
            });

            var builder = WebApplication.CreateBuilder(args);
            builder.Configuration.AddEnvironmentVariables("ABSERVER_");
            builder.WebHost.ConfigureKestrel(opt =>
            {
                opt.AllowAlternateSchemes = true;
            });

            string? appResourceName = Environment.GetEnvironmentVariable("APP_RESOURCE_NAME");
            if (appResourceName == null)
                appResourceName = "EVENTHANDLEREXTENDAPP";

            builder.Services
                .AddSingleton<IAccelByteServiceProvider, DefaultAccelByteServiceProvider>()
                .AddOpenTelemetry()
                .WithTracing((traceConfig) =>
                {
                    var asVersion = Assembly.GetEntryAssembly()!.GetName().Version;
                    string version = "0.0.0";
                    if (asVersion != null)
                        version = asVersion.ToString();

                    traceConfig
                        .AddSource(appResourceName)
                        .SetResourceBuilder(ResourceBuilder.CreateDefault()
                            .AddService(appServiceName, null, version)
                            .AddTelemetrySdk())
                        .AddZipkinExporter()
                        .AddHttpClientInstrumentation()
                        .AddAspNetCoreInstrumentation();
                });

            // Additional configuration is required to successfully run gRPC on macOS.
            // For instructions on how to configure Kestrel and gRPC clients on macOS, visit https://go.microsoft.com/fwlink/?linkid=2099682

            builder.Services.AddGrpcHealthChecks()
                .AddCheck("Health", () => HealthCheckResult.Healthy());

            builder.Services.AddGrpc((opts) =>
            {
                opts.Interceptors.Add<ExceptionHandlingInterceptor>();
                opts.Interceptors.Add<DebugLoggerServerInterceptor>();
            });
            builder.Services.AddGrpcReflection();

            var app = builder.Build();
            app.UseGrpcMetrics();

            app.MapGrpcService<UserLoggedInService>();
            app.MapGrpcReflectionService();
            app.MapGrpcHealthChecksService();
            app.MapMetrics();
            app.Run();
            return 0;
        }
    }
}
// Copyright (c) 2022-2023 AccelByte Inc. All Rights Reserved.
// This is licensed software from AccelByte Inc, for limitations
// and restrictions contact your company contract manager.

using System;
using System.Diagnostics;
using System.Diagnostics.Metrics;

using HdrHistogram;
using OpenTelemetry.Metrics;
using System.Reflection;

namespace AccelByte.PluginArch.EventHandler.Demo.Server.Metric
{
    public class RequestPercentileMetricsListener
    {
        public const string OTEL_INSTRUMENT_METER_NAME = "OpenTelemetry.Instrumentation.AspNetCore";

        public const string HTTP_DURATION_INSTRUMENT_NAME = "http.server.duration";

        public const string HTTP_LATENCY_INSTRUMENT_NAME = "http.server.latency";


        private Meter _TheMeter;

        private LongHistogram _ComputeHistogram;

        public RequestPercentileMetricsListener(string meterName, string meterVersion)
        {
            _TheMeter = new Meter(meterName, meterVersion);

            _ComputeHistogram = new LongHistogram(TimeStamp.Hours(1), 3);

            _TheMeter.CreateObservableGauge<double>(HTTP_LATENCY_INSTRUMENT_NAME + ".p99", () =>
            {
                return (double)_ComputeHistogram.GetValueAtPercentile(99) / 1000;
            }, "ms", "compute the p99 latency of HTTP requests");

            _TheMeter.CreateObservableGauge<double>(HTTP_LATENCY_INSTRUMENT_NAME + ".p95", () =>
            {
                return (double)_ComputeHistogram.GetValueAtPercentile(95) / 1000;
            }, "ms", "compute the p95 latency of HTTP requests");

            MeterListener listener = new MeterListener()
            {
                InstrumentPublished = (instrument, meterListener) =>
                {
                    if (instrument.Meter.Name == OTEL_INSTRUMENT_METER_NAME)
                        meterListener.EnableMeasurementEvents(instrument, null);
                }
            };

            //Activity.Current.Duration.TotalMilliseconds is double, make sure use the exact same type for this event callback
            listener.SetMeasurementEventCallback<double>((instrument, measurement, tags, state) =>
            {
                long adjValue = (long)Math.Round(measurement * 1000, 0);
                _ComputeHistogram.RecordValue(adjValue);
            });

            listener.Start();
        }
    }

    public static class RequestPercentileMetricsListener_Extensions
    {
        public static MeterProviderBuilder AddRequestLatencyMetric(
            this MeterProviderBuilder builder)
        {
            AssemblyName forMeterId = typeof(RequestPercentileMetricsListener).Assembly.GetName();
            string meterName = forMeterId.Name!;

            new RequestPercentileMetricsListener(meterName, forMeterId.Version!.ToString());

            return builder.AddMeter(meterName);
        }
    }
}

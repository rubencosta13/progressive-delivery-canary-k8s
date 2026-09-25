import { NodeSDK } from "@opentelemetry/sdk-node";
import "dotenv/config";
import { resourceFromAttributes } from "@opentelemetry/resources";
import { getNodeAutoInstrumentations } from "@opentelemetry/auto-instrumentations-node";
import { PeriodicExportingMetricReader } from "@opentelemetry/sdk-metrics";
import { FastifyOtelInstrumentation } from "@fastify/otel";
import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-proto";
import { OTLPMetricExporter } from "@opentelemetry/exporter-metrics-otlp-proto";
import {
  ATTR_SERVICE_NAME,
  ATTR_SERVICE_VERSION,
} from "@opentelemetry/semantic-conventions";

const sdk = new NodeSDK({
  resource: resourceFromAttributes({
    [ATTR_SERVICE_NAME]: process.env.OTEL_SERVICE_NAME ?? "my-app",
    [ATTR_SERVICE_VERSION]: process.env.APP_VERSION,
    "deployment.track": process.env.DEPLOYMENT_TRACK ?? "stable", // 'stable' | 'canary'
  }),
  traceExporter: new OTLPTraceExporter({
    url: `${process.env.OTLP_TRACE_EXPORTER_URL}`,
    headers: {},
  }),
  metricReader: new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter({
      url: `${process.env.OTLP_METRIC_EXPORTER_URL}`,
      headers: {},
    }),
  }),
  instrumentations: [
    getNodeAutoInstrumentations(),
    new FastifyOtelInstrumentation({
      registerOnInitialization: true,
    }),
  ],
  autoDetectResources: true,
});

export default sdk;

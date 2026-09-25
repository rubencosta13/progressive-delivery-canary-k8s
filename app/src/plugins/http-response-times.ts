import { metrics } from "@opentelemetry/api";
import type { FastifyInstance, FastifyRequest } from "fastify";
import { performance } from "node:perf_hooks";

const meter = metrics.getMeter("APP");

const requestDuration = meter.createHistogram("http.server.request.duration", {
  unit: "ms",
  description: "HTTP server request duration",
});

const requestCounter = meter.createCounter("http.server.request.count", {
  description: "HTTP server request count",
});

const requestStartTimes = new WeakMap<FastifyRequest, number>();

export function registerMetrics(fastify: FastifyInstance) {
  fastify.addHook("onRequest", async (request) => {
    requestStartTimes.set(request, performance.now());
  });

  fastify.addHook("onResponse", async (request, reply) => {
    const start = requestStartTimes.get(request);

    if (start === undefined) {
      return;
    }

    const duration = performance.now() - start;

    requestDuration.record(duration, {
      "http.request.method": request.method,
      "http.response.status_code": reply.statusCode,
      "url.route": request.routeOptions.url,
    });

    requestCounter.add(1, {
      "http.request.method": request.method,
      "http.response.status_code": reply.statusCode,
      "url.route": request.routeOptions.url,
    });

    requestStartTimes.delete(request);
  });
}

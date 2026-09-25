import sdk from "./otel";
sdk.start();

import Fastify from "fastify";
import { registerMetrics } from "./plugins/http-response-times";
import { controller } from "./routes/controller";

const app = Fastify();
registerMetrics(app);

console.log("[Deployment Track]: ", process.env.DEPLOYMENT_TRACK ?? "stable");

app.register(controller);


export default app;

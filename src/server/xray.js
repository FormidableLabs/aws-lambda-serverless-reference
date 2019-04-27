"use strict";

const { setLogger } = require("aws-xray-sdk-core"); // Xray
const xrayExpress = require("aws-xray-sdk-express"); // Xray
const express = require("express");

const DEFAULT_PORT = 3000;
const PORT = parseInt(process.env.SERVER_PORT || DEFAULT_PORT, 10);
const HOST = process.env.SERVER_HOST || "0.0.0.0";
const STAGE = process.env.STAGE || process.env.NODE_ENV || "localdev";
const SERVICE_NAME = process.env.SERVICE_NAME;
const SERVICE = `${SERVICE_NAME}-${STAGE}`;
const BASE_URL = process.env.BASE_URL || "/xray";

// Log xray locally.
if (STAGE === "localdev") {
  setLogger(console);
}

// The base app for any use...
const app = express();

// Settings
app.set("json spaces", 2); // eslint-disable-line no-magic-numbers

app.use(xrayExpress.openSegment(SERVICE)); // Xray

// Routes
app.use(`${BASE_URL}/*`, (req, res) => {
  res.send(`
<html>
  <body>
    <h1>The Reference App (Xray Version)!</h1>
    <p>An AWS Lambda + Serverless framework application with Xray tracing.</p>
    <p>Check Xray dashboard for samples!</p>
  </body>
</html>
  `);
});

app.use(xrayExpress.closeSegment()); // Xray

// LAMBDA: Export handler for lambda use.
let handler;
module.exports.handler = (event, context, callback) => {
  // eslint-disable-next-line global-require
  handler = handler || require("serverless-http")(app);
  return handler(event, context, callback);
};

// DOCKER/DEV/ANYTHING: Start the server directly.
if (require.main === module) {
  const server = app.listen({
    port: PORT,
    host: HOST
  }, () => {
    const { address, port } = server.address();

    // eslint-disable-next-line no-console
    console.log(`Server started at http://${address}:${port}`);
  });
}

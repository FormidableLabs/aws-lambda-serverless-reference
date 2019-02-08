"use strict";

// TODO(Xray): const { setLogger } = require("aws-xray-sdk-core"); // Xray
// TODO(Xray): const xrayExpress = require("aws-xray-sdk-express"); // Xray
const express = require("express");

const DEFAULT_PORT = 3000;
const PORT = parseInt(process.env.SERVER_PORT || DEFAULT_PORT, 10);
const HOST = process.env.SERVER_HOST || "0.0.0.0";
const BASE_URL = "/base";
// TODO(Xray)
// const STAGE = process.env.STAGE || process.env.NODE_ENV || "localdev";
// const SERVICE_NAME = process.env.SERVICE_NAME;
// const SERVICE = `${SERVICE_NAME}-${STAGE}`;

// TODO(Xray): Log xray locally.
// if (STAGE === "localdev") {
//   setLogger(console);
// }

// The base app for any use...
const app = express();

// Settings
app.set("json spaces", 2); // eslint-disable-line no-magic-numbers

// TODO(Xray): // Tracing
// app.use(xrayExpress.openSegment(SERVICE));

app.use("/favicon.ico", (req, res) => {
  res.status(404); // eslint-disable-line no-magic-numbers
  res.send("404");
});

// Root.
// Ex: http://127.0.0.1:3000/hello.json
// => `{"hello":"static REST world!"}`
app.use(`${BASE_URL}/hello.json`, (req, res) => {
  res.json({
    msg: "Simple reference serverless app!"
  });
});
app.use(`${BASE_URL}/*`, (req, res) => {
  res.send(`
<html>
  <body>
    <h1>The Reference App!</h1>
    <p>A simple AWS Lambda + Serverless framework application.</p>
  </body>
</html>
  `);
});

// TODO(Xray): // Tracing
// app.use(xrayExpress.closeSegment());

// LAMBDA: Export handler for lambda use.
let handler;
module.exports.handler = (event, context, callback) => {
  // Lazy require `serverless-http` to allow non-Lambda targets to omit.
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

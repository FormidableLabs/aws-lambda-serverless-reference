"use strict";

const express = require("express");

const DEFAULT_PORT = 3000;
const PORT = parseInt(process.env.SERVER_PORT || DEFAULT_PORT, 10);
const HOST = process.env.SERVER_HOST || "0.0.0.0";
const STAGE = process.env.STAGE || "localdev";
const BASE_URL = process.env.BASE_URL || "/layers";
const FULL_BASE_URL = STAGE === "localdev" ? BASE_URL : `/${STAGE}${BASE_URL}`;

// The base app for any use...
const app = express();

// Settings
app.set("json spaces", 2); // eslint-disable-line no-magic-numbers

// Simple test if our layers import worked.
app.use(`${BASE_URL}/layers.txt`, async (req, res) => {
  let msg;

  // Dependencies layer
  try {
    // eslint-disable-next-line global-require,import/no-unresolved
    const figlet = require("figlet");
    msg = figlet.textSync("Hello Layers");
  } catch (e) {
    msg = "Could not import figlet via layers. Sorry, no ASCII art today... :(";
  }

  // No dependencies layer
  try {
    // eslint-disable-next-line global-require,import/no-unresolved
    const { repeat } = require("/opt/repeat");
    msg += `\n\n${repeat("-", msg.split("\n")[0].length)}`;
  } catch (e) {
    msg += "\n\nCould not import repeat via layers. Sorry, no exclamations today... :(";
  }

  res.set("Content-Type", "text/plain");
  res.send(msg);
});
app.use(`${BASE_URL}/*`, (req, res) => {
  res.send(`
<html>
  <body>
    <h1>The Reference App (Layers Edition)!</h1>
    <p>A simple AWS Lambda + Serverless framework application.</p>
    <p>
      See layers response:
      <a href="${FULL_BASE_URL}/layers.txt"><code>${FULL_BASE_URL}/layers.txt</code></a>
    </p>
  </body>
</html>
  `);
});

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

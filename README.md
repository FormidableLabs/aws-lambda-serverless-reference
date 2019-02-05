AWS Lambda Serverless Reference
===============================

A simple "hello world" reference app using the [serverless][] framework targeting an AWS Lambda deploy.

## Overview

Although this app is super simple, we have somewhat complex development workflows, cloud infrastructure, and deployment/operations workflows. The point of this project is to not lose focus on "the app" and get all the _other_ things in place to support taking any server application to production on AWS Lambda using the serverless framework.

### Stack

We use very simple, very common tools to allow a mostly vanilla Express server to run in localdev / Docker like a normal Node.js HTTP server and _also_ as a Lambda function exposed via API Gateway.

Tech stack:

* [`express`](serverless-http): A server.

Infrastructure stack:

* [serverless][]: Build / deployment framework for getting code to Lambda.
* [serverless-http][]: Bridge to make a vanilla Express server run on Lambda.

### Naming

We use a naming convention in cloud resources and `yarn` tasks to separate some various high level things:

* `aws`: AWS specific names and files (`./aws/`).
* `tf`: Terraform specific names and files (`./terraform`).
* `sls`: Serverless framework names.

### Stages

Development hits a local machine, and when programmatically named, is usually referred to as:

* `localdev`: A development-only setup running on a local machine.

We target four different stages/environments of AWS hosted deployments:

* `sandbox`: A loose environment where developers can manually push / check things / break things with impunity. Typically deployed from developer laptops.
* `development`: Tracks feature development branches. Typically deployed by CI on merges to `develop` branch if using git flow workflow.
* `staging`: A near-production environment to validate changes before committing to actual production. Typically deployed by CI for release candidate branches before merging to `master`.
* `production`: The real deal. Typically deployed by CI after a merge to `master`.

Note that these are completely arbitrary groups, both in composition and naming. There a sensible set of groups if you need just some starting point. But the final group (or even one if you want) is totally up to you!

All of our `yarn run <task>` tasks should be run with a `STAGE=<value>` prefix. The default is to assume `STAGE=localdev` and only commands like `yarn run node:localdev` or `yarn run lambda:localdev` can run without specification successfully. For commands actually targeting AWS, please prefix like:

```sh
$ STAGE=sandbox yarn run <task>
$ STAGE=development yarn run <task>
$ STAGE=stage yarn run <task>
$ STAGE=production yarn run <task>
```

_Note_: We separate the `STAGE` variable from `NODE_ENV` because often there are build implications of `NODE_ENV` that are distinct from our notion of deploy target environments.

### Environment Variables

Our task runner scheme is a bash + `yarn` based system crafted around the following environment variables (with defaults):

* `STAGE`: `localdev`
* `SERVICE_NAME`: `simple-reference` (The name of the application/service in the cloud.)
* `AWS_REGION`: `us-east-1`

... and some minor localdev only ones:

* `AWS_XRAY_CONTEXT_MISSING`: `LOG_ERROR` (Have Xray not error in localdev)
* `SERVER_PORT`: `3000`
* `SERVER_HOST`: `0.0.0.0`

If your project supports Windows, you will want to have a more general / permissive approach.





TODO_REST_OF_DOCS

[serverless]: https://serverless.com/
[serverless-http]: https://github.com/dougmoscrop/serverless-http

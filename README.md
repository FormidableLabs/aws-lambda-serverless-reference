AWS Lambda Serverless Reference
===============================

A simple "hello world" reference app using the [serverless][] framework targeting an AWS Lambda deploy.

## Contents

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->


- [Overview](#overview)
  - [Stack](#stack)
  - [Naming](#naming)
  - [Stages](#stages)
  - [Environment Variables](#environment-variables)
- [Installation](#installation)
  - [Node.js (Runtime)](#nodejs-runtime)
  - [AWS (Deployment)](#aws-deployment)
    - [AWS Tools](#aws-tools)
    - [AWS Credentials](#aws-credentials)
      - [In Environment](#in-environment)
      - [Saved to Local Disk](#saved-to-local-disk)
      - [AWS Vault](#aws-vault)
- [Development](#development)
  - [Node.js](#nodejs)
  - [Lambda Offline](#lambda-offline)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Overview

Although this app is super simple, we have somewhat complex development workflows, cloud infrastructure, and deployment/operations workflows. The point of this project is to not lose focus on "the app" and get all the _other_ things in place to support taking any server application to production on AWS Lambda using the serverless framework.

### Stack

We use very simple, very common tools to allow a mostly vanilla Express server to run in localdev / Docker like a normal Node.js HTTP server and _also_ as a Lambda function exposed via API Gateway.

Tech stack:

* [`express`](serverless-http): A server.

Infrastructure stack:

* [serverless][]: Build / deployment framework for getting code to Lambda.
* [serverless-http][]: Bridge to make a vanilla Express server run on Lambda.

Infrastructure tools:

* AWS [CloudFormation][]: Create AWS cloud resources using YAML. The `serverless` framework creates a CloudFormation stack of Lambda-supporting resources as part of a normal deployment. This project also uses a small CloudFormation stack to bootstrap an S3 bucket and DynamoDB to handle Terraform state.
* HashiCorp [Terraform][]: Create AWS cloud resources using [HCL][]. Typically more flexible and expressive than CloudFormation. We have a simple Terraform stack that uses a plugin to set up a production-ready set of resources (IAM, monitoring, etc.) to support the resources/stack generated by `serverless`.

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

## Installation

### Node.js (Runtime)

Our application is a Node.js server.

First, make sure you have our version of node (determined by `.nvmrc`) that matches our Lambda target (you will need to have [`nvm`](https://github.com/creationix/nvm) installed):

```sh
$ nvm use
```

Then, `yarn` install the Node.js dependencies:

```sh
$ yarn install
```

### AWS (Deployment)

#### AWS Tools

Certain administrative / development work require the AWS CLI tools to prepare and deploy our staging / production services. To get those either do:

```sh
# Install via Python
$ sudo pip install awscli --ignore-installed six

# Or brew
$ brew install awscli
```

After this you should be able to type:

```sh
$ aws --version
```

#### AWS Credentials

To work with our cloud tools, you need AWS credentials for your specific user  (aka, `FIRST.LAST`). If you don't have an AWS user with access to the `aws-${SERVICE_NAME}-${STAGE}-(admin|developer)` IAM group, then request one from your manager.

Once you have a user + access + secret keys, you need to make them available to commands requiring them. There are a couple of options:

##### In Environment

You can append the following two environment variables to any command like:

```sh
$ AWS_ACCESS_KEY_ID=INSERT \
  AWS_SECRET_ACCESS_KEY=INSERT \
  STAGE=sandbox \
  yarn run lambda:info
```

This has the advantage of not storing secrets on disk. The disadvantage is needing to keep the secrets around to paste and/or `export` into every new terminal.

##### Saved to Local Disk

Another option is to store the secrets on disk. You can configure your `~/.aws` credentials like:

```sh
$ mkdir -p ~/.aws
$ touch ~/.aws/credentials
```

Then add a `default` entry if you only anticipate working on this one project  or a named profile entry of your username (aka, `FIRST.LAST`):

```sh
$ vim ~/.aws/credentials
[default|FIRST.LAST]
aws_access_key_id = INSERT
aws_secret_access_key = INSERT
```

If you are using a named profile, then export it into the environment in any terminal you are working in:

```sh
$ export AWS_PROFILE="FIRST.LAST"
$ STAGE=sandbox yarn run lambda:info
```

Or, you can declare the variable inline:

```sh
$ AWS_PROFILE="FIRST.LAST"\
  STAGE=sandbox \
  yarn run lambda:info
```

##### AWS Vault

The most secure mix of the two above options is to install and use [aws-vault](https://github.com/99designs/aws-vault). Once you've followed the installation instructions, you can set up and use a profile like:

```sh
# Store AWS credentials for a profile named "FIRST.LAST"
$ aws-vault add FIRST.LAST
Enter Access Key Id: INSERT
Enter Secret Key: INSERT

# Execute a command with temporary creds
$ aws-vault exec FIRST.LAST -- STAGE=sandbox yarn run lambda:info
```

## Development

We have several options for developing a service locally, with different
advantages. Here's a quick list of application ports / running commands:

* `3000`: Node server via `nodemon`. (`yarn node:localdev`)
* `3001`: Lambda offline local simulation. (`yarn lambda:localdev`)

### Node.js

Run the server straight up in your terminal with Node.js via `nodemon` for
instant restarts on changes:

```sh
$ yarn node:localdev
```

See it in action!:

- [http://127.0.0.1:3000/hello.json](http://127.0.0.1:3000/hello.json)

Or from the command line:

```sh
$ curl -X POST "http://127.0.0.1:3000/hello.json" \
  -H "Content-Type: application/json"
```

### Lambda Offline

Run the server in a Lambda simulation via the [`serverless-offline`](https://github.com/dherault/serverless-offline) plugin

```sh
$ yarn lambda:localdev
```

See it in action!:

- [http://127.0.0.1:3001/hello.json](http://127.0.0.1:3001/hello.json)




TODO_REST_OF_DOCS

[serverless]: https://serverless.com/
[serverless-http]: https://github.com/dougmoscrop/serverless-http
[CloudFormation]: https://aws.amazon.com/cloudformation/
[Terraform]: https://www.terraform.io
[HCL]: https://www.terraform.io/docs/configuration/syntax.html

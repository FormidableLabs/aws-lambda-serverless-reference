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
  - [User Roles](#user-roles)
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
- [Support Stack Provisioning (Superuser)](#support-stack-provisioning-superuser)
  - [Bootstrap Stack](#bootstrap-stack)
  - [Service Stack](#service-stack)
- [Serverless Deployment (IAM Roles)](#serverless-deployment-iam-roles)
  - [Admin Deployment](#admin-deployment)
  - [User Deployment](#user-deployment)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Overview

Getting a `serverless` application into the cloud "the right way" can be a challenge. To this end, we start with a super-simple, "hello world" Express app targeting AWS Lambda using serverless. Along the way, this reference project takes care of all of the **tough** supporting pieces that go into a production-ready, best-practices-following cloud infrastructure like:

- Local development workflows.
- Terraform stack controlling IAM permissions and cloud resources to support a vanilla `serverless` application.
- Remote state management for Terraform.
- Serverless application deployment and production lifecycle management.

Using this project as a template, you can hopefully take a new `serverless` application and set up "everything else" to support it in AWS the right way, from the start.

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

* `cf`: AWS CloudFormation specific names.
* `tf`: Terraform specific names.
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

### User Roles

We rely on IAM roles to limit privileges to the minimum necessary to provision, update, and deploy the service. Typically this involves creating personalized users in the AWS console, and then assigning them groups for varying appropriate degrees of privilege. Here are the relevant ones for this reference project:

- **Superuser - Support Stack**: A privileged user that can create the initial bootstrap CloudFormation stack and Terraform service module that will support a Serverless application. It should not be used for Serverless deploys.
- **IAM Groups - Serverless App**: The TODO_INSERT_MODULE_LINK_AND_NAME module provides IAM groups and support for different types of users to create/update/delete the Serverless application. The IAM groups created are:
    - `tf-${SERVICE_NAME}-${STAGE}-admin`: Can create/delete/update the Lambda
      service.
    - `tf-${SERVICE_NAME}-${STAGE}-developer`: Can deploy the Lambda service.
    - `tf-${SERVICE_NAME}-${STAGE}-ci`: Can deploy the Lambda service.

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

To work with our cloud tools, you need AWS credentials for your specific user  (aka, `FIRST.LAST`). If you don't have an AWS user with access to the `tf-${SERVICE_NAME}-${STAGE}-(admin|developer)` IAM group, then request one from your manager.

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

The most secure mix of the two above options is to install and use
[aws-vault](https://github.com/99designs/aws-vault). Once you've followed the installation instructions, you can set up and use a profile like:

```sh
# Store AWS credentials for a profile named "FIRST.LAST"
$ aws-vault add FIRST.LAST
Enter Access Key Id: INSERT
Enter Secret Key: INSERT

# Execute a command with temporary creds
$ aws-vault exec FIRST.LAST -- STAGE=sandbox yarn run lambda:info
```

## Development

We have several options for developing a service locally, with different advantages. Here's a quick list of application ports / running commands:

* `3000`: Node server via `nodemon`. (`yarn node:localdev`)
* `3001`: Lambda offline local simulation. (`yarn lambda:localdev`)

### Node.js

Run the server straight up in your terminal with Node.js via `nodemon` for instant restarts on changes:

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

## Support Stack Provisioning (Superuser)

This section discusses getting AWS resources provisioned to support Terraform and then Serverless.

The basic overview is:

1. **Bootstrap Stack**: Use AWS CloudFormation to provision resources to manage Terraform state.
2. **Service Stack**: Use Terraform to provision resources / permissions to accompany a Serverless deploy.

after this, _then_ we are ready to deploy a standard `serverless` application with full support!

### Bootstrap Stack

This step creates an S3 bucket and DynamoDB data store to enable Terraform to remotely manage it's state. We do this via AWS CloudFormation.

All commands in this section should be run by an AWS superuser. The configuration for all of this section is controlled by: [`aws/bootstrap.yml`](./aws/bootstrap.yml). Commands and resources created are all prefixed with `cf` as a project-specific choice for ease of identification in the AWS console (vs. Terraform vs. Serverless-generated).

**Create** the CloudFormation stack:

```sh
# Provision stack.
$ STAGE=sandbox yarn run cf:bootstrap:create
{
    "StackId": "arn:aws:cloudformation:${AWS_REGION}:${AWS_ACCOUNT}:stack/cf-${SERVICE_NAME}-${STAGE}-bootstrap/HASH"
}

# Check status until reach `CREATE_COMPLETE`
$ STAGE=sandbox yarn run cf:bootstrap:status
"CREATE_COMPLETE"
```

Once this is complete, you can move on to provisioning the service stack section. The remaining commands below are only if you need to update / delete the bootstrap stack, which shouldn't happen that often.

**Update** the CloudFormation stack:

```sh
# Update, then check status.
$ STAGE=sandbox yarn run cf:bootstrap:update
$ STAGE=sandbox yarn run cf:status
```

**Delete** the CloudFormation stack:

The bootstrap stack should only be deleted _after_ you have removed all of the `-admin|-developer|-ci` groups from users and deleted the Serverless and Terraform service stacks.

```sh
# **WARNING**: Use with extreme caution!!!
$ STAGE=sandbox yarn run cf:bootstrap:_delete

# Check status. (A status or error with `does not exist` when done).
$ STAGE=sandbox yarn run cf:bootstrap:status
An error occurred (ValidationError) when calling the DescribeStacks operation: Stack with id aws-SERVICE_NAME-STAGE does not exist
```

### Service Stack

This step provisions a Terraform stack to provide us with IAM groups and other AWS resources to support and enhance a Serverless provision (in the next section).

All commands in this section should be run by an AWS superuser.  The configuration for all of this section is controlled by: [`terraform/main.tf`](./terraform/main.tf). Commands and resources created are all prefixed with `tf` as a project-specific choice for ease of identification.

**Init** your local Terraform state.

This needs to be run once to be able to run any other Terraform commands.

```sh
$ STAGE=sandbox yarn run tf:service:init
```

**Plan** the Terraform stack.

Terraform allows you to see what's going to happen / change in your cloud infrastructure before actually committing to it, so it is _always_ a good idea to run a plan before any Terraform mutating command.

```sh
$ STAGE=sandbox yarn run tf:service:plan
```

**Apply** the Terraform stack:

This creates / updates as appropriate.

```sh
# Type in `yes` to go forward
$ STAGE=sandbox yarn run tf:service:apply

# YOLO: run without checking first
$ STAGE=sandbox yarn run tf:service:apply -auto-approve
```

**Delete** the Terraform stack:

The service stack should only be deleted _after_ you have removed all of the `-admin|-developer|-ci` groups from users and deleted the Serverless stack.

```sh
# **WARNING**: Use with extreme caution!!!
# Type in `yes` to go forward
$ STAGE=sandbox yarn run tf:service:_delete

# YOLO: run without checking first
$ STAGE=sandbox yarn run tf:service:_delete -auto-approve
```

**Visualize** the Terraform stack:

These are Mac-based instructions, but analogous steps are available on other platforms. First, you'll need GraphViz for the `dot` tool:

```sh
$ brew install graphviz
```

From there, you can visualize with:

```sh
# Generate SVG
$ STAGE=sandbox yarn run -s tf:terraform graph | dot -Tsvg > ~/Desktop/infrastructure.svg
```

## Serverless Deployment (IAM Roles)

This section discusses developers getting code and secrets deployed (manually from local machines to an AWS `development` playground or automated via CI).

All commands in this section should be run by AWS users with attached IAM groups provisioned by our support stack of `tf-${SERVICE_NAME}-${STAGE}-(admin|developer|ci)`. The configuration for this section is controlled by: [`serverless.yml`](./serverless.yml)

### Admin Deployment

These actions are reserved for `-admin` users.

**Create** the Lambda app. The first time through a `deploy`, an `-admin` user
is required (to effect the underlying CloudFormation changes).

```sh
$ STAGE=sandbox yarn run lambda:deploy

# Check on app and endpoints.
$ STAGE=sandbox yarn run lambda:info
```

**Delete** the Lambda app.

```sh
# TODO: TEST OUT
# **WARNING**: Use with extreme caution!!!
$ STAGE=sandbox yarn run lambda:_delete
```

**Metrics**:

```sh
# Show metrics for an application
$ STAGE=sandbox yarn run lambda:metrics
```

### User Deployment

These actions can be performed by any user (`-admin|developer|ci`).

Get server **information**:

```sh
$ STAGE=sandbox yarn run lambda:info
...
endpoints:
  ANY - https://HASH.execute-api.AWS_REGION.amazonaws.com/STAGE
  ANY - https://HASH.execute-api.AWS_REGION.amazonaws.com/STAGE/{proxy+}
...
```

See the **logs**:

```sh
$ STAGE=sandbox yarn run lambda:logs
```

**Update** the Lambda server.

```sh
$ STAGE=sandbox yarn run lambda:deploy
```

**Rollback** to a previous Lamba deployment:

If something has gone wrong, you can see the list of available states to
roll back to with:

```sh
$ STAGE=sandbox yarn lambda:rollback
```

Then choose a datestamp and add with the `-t` flag like:

```sh
$ STAGE=sandbox yarn lambda:rollback -t 2019-02-07T00:35:56.362Z
```

[serverless]: https://serverless.com/
[serverless-http]: https://github.com/dougmoscrop/serverless-http
[CloudFormation]: https://aws.amazon.com/cloudformation/
[Terraform]: https://www.terraform.io
[HCL]: https://www.terraform.io/docs/configuration/syntax.html

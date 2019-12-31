Learning 🎓
==========

This project's primary audience is experienced cloud infrastructure folks looking to production-ize a modern Serverless stack in a single AWS account. But, it's also an appropriate place to learn the various parts along the way!

## Contents

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->


- [Projects](#projects)
- [Getting Started](#getting-started)
- [Exercises](#exercises)
  - [Environments](#environments)
  - [Lambda Exercises](#lambda-exercises)
  - [Infrastructure Exercises](#infrastructure-exercises)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Projects

We have **two** main reference projects from which to learn:

* [aws-lambda-serverless-reference](https://github.com/FormidableLabs/aws-lambda-serverless-reference): (**This project!**) Our most basic Serverless reference with a full production infrastructure. If you're unsure of where to begin, start here.
* [badges](https://github.com/FormidableLabs/badges): Our advanced reference project that includes more complex enhancements like: per-PR environments, github-flow support, promote-to-production artifacts, etc. Once you've mastered manual CF + TF + SLS deploys, come over here and see how far automation can take us!

## Getting Started

1. (_For Formidables only_). Contact Roemer to get three AWS IAM users. The `-developer` and `-admin` users will be manually attached to the appropriate `sandbox` stage groups (`tf-simple-reference-sandbox-developer`, `tf-simple-reference-sandbox-admin`) for use with `serverless` commands.
    1. `FIRST.LAST` user: An AWS superadmin that can do things like deploy the bootstrap CloudFormation and service Terraform infrastructures. This user reflects a DevOps lead in a client project. Should only be used for `yarn cf:*` and `yarn tf:*` commands.
    2. `FIRST.LAST-developer` user: A user with IAM group permissions for the specific serverless project + `STAGE` to update an existing deployment. This reflects an engineer on a client project with limited privileges or maybe a CI system for staging or whatnot. Should only be used for `yarn lambda:*` commands.
    3. `FIRST.LAST-admin` user: A user with IAM group permissions for the specific serverless project + `STAGE` to update + create/delete any deployment. This reflects an engineer on a client project with full privileges over the serverless application, but not the supporting cloud infrastructure. Should only be used for `yarn lambda:*` commands.

2. Then, follow all the basic directions for installation in the [README](./README.md).
    1. (_For Formidables only_). Please set up `aws-vault` per the instructions for your authentication method.

3. Check that your credentials are set up for all appropriate work:

    ```sh
    # 1. Check CloudFormation as superadmin
    $ STAGE=sandbox aws-vault exec FIRST.LAST --no-session -- \
      yarn cf:bootstrap:status
    ...
    "UPDATE_COMPLETE" # (or some other status)

    # 2. Check Terraform as superadmin
    # 2.a. Init to appropriate stage backend.
    $ STAGE=sandbox aws-vault exec FIRST.LAST --no-session -- \
      yarn tf:service:init --reconfigure
    ...
    Terraform has been successfully initialized!

    # 2.b. Run plan to see any changes from our code vs. actual infrastructure.
    $ STAGE=sandbox aws-vault exec FIRST.LAST --no-session -- \
      yarn tf:service:plan
    ...
    No changes. Infrastructure is up-to-date.

    # 3. Check Serverless as `-developer`
    $ STAGE=sandbox aws-vault exec FIRST.LAST-developer --no-session -- \
      yarn lambda:info
    ...
    Service Information
    service: sls-simple-reference
    stage: sandbox
    region: us-east-1
    stack: sls-simple-reference-sandbox
    ...
    ```

## Exercises

### Environments

> `tl:dr`: use `sandbox` and only do `yarn lambda:*` commands for intro exercises.

**Lambda**

All of the introductory exercises are performed in the pre-existing `sandbox` environment using only `yarn lambda:*` commands to do serverless deployments as an `-admin` or `-developer` user. This means that you should just let folks know in an appropriate channel that you are "taking over" the environment.

**Infrastructure** (_CloudFormation + Terraform_)

Your superadmin user should be reserved only for work on _new_ environments. If you choose to do a new environment, it is _very important_ that you talk to Tyler or Roemer and refactor this application to grep and comment out all sections titled `OPTION` in `serverless.yml` and `terraform/main.tf` to remove all the extra bells and whistles (particularly VPC which is slow and complicates things) in a temporary branch to make your infrastructure work much easier and more focused.

### Lambda Exercises

1. Completely review and read the `README.md` one more time and ask questions in a slack channel!

1. Do a deployment of the serverless branch as-is off `master` branch:

    ```sh
    $ STAGE=sandbox aws-vault exec FIRST.LAST-developer --no-session -- \
      yarn lambda:deploy
    ```

    ... then go and kick the tires on a URL! 
    
    The endpoints created will be listed under `endpoints` in the console output.  Please note that the endpoints MUST end with `/`.  If the output is `https://ii178wi5hi.execute-api.us-east-1.amazonaws.com/sandbox/base`, then you must use `https://ii178wi5hi.execute-api.us-east-1.amazonaws.com/sandbox/base/` (notice the trailing `/`) in your browser.

1. Delete the serverless application and re-deploy it as-is off `master` branch:

    ```sh
    # Be careful!
    $ STAGE=sandbox aws-vault exec FIRST.LAST-admin --no-session -- \
      yarn lambda:_delete

    # Now, the `lambda:deploy` command needs an `-admin` user to create.
    $ STAGE=sandbox aws-vault exec FIRST.LAST-admin --no-session -- \
      yarn lambda:deploy
    ```

1. Create a temporary branch and edit something in `src/server/base.js` that will be visible from a public URL. Then deploy it and check the results!

    ```sh
    $ STAGE=sandbox aws-vault exec FIRST.LAST-developer --no-session -- \
      yarn lambda:deploy
    ```

1. See if there are any [open issues](https://github.com/FormidableLabs/aws-lambda-serverless-reference/issues) that need just a serverless / application code fix and try to open a pull request! Or, be a saint and update all the root project dependencies in `package.json` to keep us up to date, verify everything still works, and open a pull request.

### Infrastructure Exercises

Once you've got the basics of serverless deployment down, you can move on to doing things with your AWS superadmin user to the infrastructure.

1. Check the status of the CloudFormation bootstrap stack and attempt an update:

    ```sh
    # Check the existing status.
    $ STAGE=sandbox aws-vault exec FIRST.LAST --no-session -- \
      yarn cf:bootstrap:status
    ...
    "UPDATE_COMPLETE"

    # Attempt an update. If everything is up-to-date on master, you'll get an expected error.
    $ STAGE=sandbox aws-vault exec FIRST.LAST --no-session -- \
      yarn cf:bootstrap:update
    ...
    An error occurred (ValidationError) when calling the UpdateStack operation: No updates are to be performed.
    ```

1. Check the status of the Terraform service stack and attempt an update:

    ```sh
    # Init to appropriate stage backend.
    $ STAGE=sandbox aws-vault exec FIRST.LAST --no-session -- \
      yarn tf:service:init --reconfigure
    ...
    Terraform has been successfully initialized!

    # Run plan to see any changes from our code vs. actual infrastructure.
    $ STAGE=sandbox aws-vault exec FIRST.LAST --no-session -- \
      yarn tf:service:plan
    ...
    No changes. Infrastructure is up-to-date.


    # Run apply to make changes (or no-op) from our code vs. actual infrastructure.
    $ STAGE=sandbox aws-vault exec FIRST.LAST --no-session -- \
      yarn tf:service:apply
    ...
    Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

    # **NOTE**: If there are changes needed, you will type "yes" at the prompt.
    ```

1. Create a new environment named `sandbox-FIRST-LAST`, just for you!
    1. Create a new temporary branch off the repo (not a fork) so that other Formidables can easily jump in and help you.
    2. Per the instructions above, make sure to talk to Tyler or Roemer and comment out / disable all `OPTION` sections in `serverless.yml`, `terraform/main.tf` and `terraform/role-ci.tf` in your branch and have them review and approve the tentative changes before trying any real AWS provisioning actions.
    3. Once everything is ready, go ahead and provision your entire infrastructure and then application!

        ```sh
        # Create the CloudFormation bootstrap stack
        $ STAGE=sandbox-FIRST-LAST aws-vault exec FIRST.LAST --no-session -- \
          yarn cf:bootstrap:create

        # Confirm done in `CREATE|UPDATE_COMPLETE` status.
        $ STAGE=sandbox-FIRST-LAST aws-vault exec FIRST.LAST --no-session -- \
          yarn cf:bootstrap:status

        # Create the Terraform service stack
        $ STAGE=sandbox-FIRST-LAST aws-vault exec FIRST.LAST --no-session -- \
          yarn tf:service:init --reconfigure

        $ STAGE=sandbox-FIRST-LAST aws-vault exec FIRST.LAST --no-session -- \
          yarn tf:service:apply
        # Type "yes" at prompt for resource creation after a review

        # Deploy the serverless app as `-admin`
        $ STAGE=sandbox-FIRST-LAST aws-vault exec FIRST.LAST-admin --no-session -- \
          yarn lambda:deploy
        ```

    4. Go kick the tires on your new service or get help in Slack if things are going wrong. Experiment with the app or the Terraform infastructure with suggestions from your colleagues.
    5. When you're finished, tear everything down in reverse order:


        ```sh
        # Delete the serverless app as `-admin`
        $ STAGE=sandbox-FIRST-LAST aws-vault exec FIRST.LAST-admin --no-session -- \
          yarn lambda:_delete

        # Delete Terraform support stack
        $ STAGE=sandbox-FIRST-LAST aws-vault exec FIRST.LAST --no-session -- \
          yarn tf:service:_delete
        # Type "yes" if prompted

        # Delete the CloudFormation bootstrap stack
        $ STAGE=sandbox-FIRST-LAST aws-vault exec FIRST.LAST --no-session -- \
          yarn cf:bootstrap:_delete
        ```

1. See if there are any [open issues](https://github.com/FormidableLabs/aws-lambda-serverless-reference/issues) that need an infrastructure code fix. Talk to your peers in Slack channel as to how best to develop the changes (a separate dedicated environment, or just YOLO-ing it in `sandbox`), then try to open a pull request!

1. Once you're comfortable with all the infrastructure parts in this project, head on over to our [badges](https://github.com/FormidableLabs/badges) project to learn the advanced next steps of a whole lot more automation and cloud infrastructure complexity!

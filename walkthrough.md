# Walkthrough - SNS Notifications to Discord for Cloudwatch Alarms using Terraform

This walkthrough will provide step-by-step instructions on how to setup SNS notifications to a Discord server and channel of your choosing. 

Please note that this focuses on sending Cloudwatch alarm notifications but can definitely be adapted to any other service that can utilise AWS SNS (as long as you are aware of the message format).

Below is a quick diagram of the architecture




# Table of Contents

- [1. Discord webook](#1-discord-webhook)
- [2. Setting up your Terraform environment](#2-setting-up-your-terraform-environment)

## 1. Discord webhook

You can follow the steps listed on this [webpage](https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks) to generate your webhook for the server and channel of your choosing.

Ensure you have copied the webhook URL after it gets generated.

## 2. Setting up your Terraform environment

### 2.1 Providers template

You can access the template file here: [providers.tf](https://www.github.com/OTarique/SNS_Discord/providers.tf)

Please ensure you edit the following fields based on your AWS region and profile name as configured on your machine.

```ruby
provider "aws" {
  region = "{enter your region here}"
  profile = "{enter your profile here}"
}
```
### 2.2 Variables templates

Please edit the variable names and descriptions as you see fit in the [variables.tf](https://www.github.com/OTarique/SNS_Discord/variables.tf) file.

Thereafter, edit the [terraform.tfvars](https://www.github.com/OTarique/SNS_Discord/terraform.tfvars) with the actual values for the variables. Important that you paste the webhook url in the applicable variable as this will be needed later.

```ruby
discord_webhook = "{enter your webhook here}"
```
## 3. Main configurations

All the configurations needed in your AWS account is setup in the [main.tf](https://www.github.com/OTarique/SNS_Discord/main.tf)

You can definitely split up each configuration into its own .tf file if you prefer.

Morever, I have named each resource variable as 'example'. Please change it to a variable name of your choosing. This also applies to the any 'name' variable in any resource.

### 3.1 SNS Topic

Set up your SNS topic.

```ruby
resource "aws_sns_topic" "example" {
  name = "SNS_Notifications_Discord" #rename this
  tags = var.common_tags
}
```
### 3.2 Parameter Store

To keep things secure, we will create a Parameter Store on AWS Systems Manager for our Discord Webhook. This will be retrived by our Lambda function on invocation.

```ruby
resource "aws_ssm_parameter" "example" {
  name        = "DiscordWebHook" #rename this
  description = "Discord webhook for alarms" #rename this
  type        = "SecureString"
  key_id      = "alias/aws/ssm"
  value       = var.discord_webhook

  tags = var.common_tags
}
```
### 3.3 IAM

We will need to create a role with permissions that allow the Lambda function to execute the necessary operations.

First we create a role with access to the Lambda.
```ruby
resource "aws_iam_role" "example" {
  name = "discord_role" #rename this

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
})
}
```
Next we create a set of permissions that will:
- Retrieve Discord webhook URL from Parameter Store
- Write to Cloudwatch logs

```ruby
data "aws_iam_policy_document" "example" {
  statement {
    sid = "ssm"
    effect = "Allow"
    actions = [ "ssm:Describe*",
                "ssm:Get*",
                "ssm:List*"]
    resources = [ "${aws_ssm_parameter.example.arn}" ]
  }

    statement {
    sid = "cloudwatch"
    effect = "Allow"
    actions = [ "logs:CreateLogStream","logs:PutLogEvents","logs:CreateLogStream","logs:CreateLogGroup"]
    resources = [ "arn:aws:logs:*:*:*"]
  }
}
```
Lastly, we will attach this policy to the role.

```ruby
resource "aws_iam_role_policy" "example" {
  name = "discord_role_permissions" #rename this
  role = aws_iam_role.example.id
  policy = data.aws_iam_policy_document.example.json
}
```
### 3.4 Lambda function
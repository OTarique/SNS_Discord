#If you see any place with the word 'example', replace it with a name of your choosing.

#Creating the SNS topic
resource "aws_sns_topic" "example" {
  name = "SNS_Notifications_Discord" #rename this to anything you would like
  tags = var.common_tags
}

#Create a Parameter Store that contains your Discord Webhook
resource "aws_ssm_parameter" "example" {
  name        = "DiscordWebHook" #rename this to anything you would like
  description = "Discord webhook for alarms"
  type        = "SecureString"
  key_id      = "alias/aws/ssm"
  value       = var.discord_webhook

  tags = var.common_tags
}

##Lambda Function Section

#Create a role for lambda function
resource "aws_iam_role" "example" {
  name = "discord_role" #rename this to anything you would like

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

#Create a policy document to attach to the role. This will grant access to fetch the Discord Webhook from Parameter Store
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

#Apply the policy to the role
resource "aws_iam_role_policy" "example" {
  name = "discord_role_permissions" #rename this to anything you would like
  role = aws_iam_role.example.id
  policy = data.aws_iam_policy_document.example.json
}

#Lambda function setup
data "archive_file" "example" {
  type        = "zip"
  source_file = "mySNSDiscordFunc.py" #please rename this to your python file name
  output_path = "mySNSDiscordFunc.zip" #please rename this to your python file name
}

resource "aws_lambda_function" "example" {
  filename          = data.archive_file.example.output_path
  function_name     = "mySNSDiscordFunc"
  role              = aws_iam_role.example.arn
  source_code_hash  = data.archive_file.example.output_base64sha256
  handler           = "mySNSDiscordFunc.lambda_handler" #name of file.function name in py file
  runtime           = "python3.7"
  timeout           = "1"

  environment {
    variables = {
      ssm_name = "${aws_ssm_parameter.example.name}"
      project_name = "Notification from ${var.project_name}"
    }
  }

  tags = var.common_tags

}

#Adding trigger to lambda function so it executes when SNS is triggered
resource "aws_lambda_permission" "example" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example.function_name
  principal     = "sns.amazonaws.com"

  source_arn = "${aws_sns_topic.example.arn}"
}

#Adding the lambda function as a subscription to the SNS Topic
resource "aws_sns_topic_subscription" "example" {
  topic_arn = aws_sns_topic.example.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.example.arn
}

#Adding a log group to cloudwatch for tracking.
resource "aws_cloudwatch_log_group" "example" {
  name = "/aws/lambda/${aws_lambda_function.example.function_name}"
  retention_in_days = 30
}
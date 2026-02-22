resource "aws_iam_user" "cd" {
  name = "cicd-bot"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_access_key" "cd" {
  user = aws_iam_user.cd.name

  lifecycle {
    prevent_destroy = true
  }
}

data "aws_iam_policy_document" "tf_s3_backend" {
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.tf_state_bucket}"]
  }

  statement {
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [
      "arn:aws:s3:::${var.tf_state_bucket}/${var.tf_state_key}"
    ]
  }
}

data "aws_iam_policy_document" "tf_dynamodb_backend" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem"
    ]
    resources = ["arn:aws:dynamodb:*:*:table/${var.tf_state_lock_table}"]
  }
}

resource "aws_iam_policy" "tf_s3_backend" {
  name        = "${aws_iam_user.cd.name}-tf-s3"
  description = "Allow user to use S3"
  policy      = data.aws_iam_policy_document.tf_s3_backend.json
}

resource "aws_iam_policy" "tf_dynamodb_backend" {
  name        = "${aws_iam_user.cd.name}-tf-dynamodb"
  description = "Allow user to use DynamoDB for TF backend resources"
  policy      = data.aws_iam_policy_document.tf_dynamodb_backend.json
}

resource "aws_iam_user_policy_attachment" "tf_s3_backend" {
  user       = aws_iam_user.cd.name
  policy_arn = aws_iam_policy.tf_s3_backend.arn
}

resource "aws_iam_user_policy_attachment" "tf_dynamodb_backend" {
  user       = aws_iam_user.cd.name
  policy_arn = aws_iam_policy.tf_dynamodb_backend.arn
}

resource "aws_iam_user_policy_attachment" "admin_access" {
  user       = aws_iam_user.cd.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

data "aws_iam_policy_document" "load_balancer_controller_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.cluster.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "load_balancer_controller" {
  name               = "${var.cluster_name}-load-balancer-controller"
  description        = "IRSA role for the AWS Load Balancer Controller."
  assume_role_policy = data.aws_iam_policy_document.load_balancer_controller_assume_role.json
}

resource "aws_iam_policy" "load_balancer_controller" {
  name        = "${var.cluster_name}-load-balancer-controller"
  description = "AWS Load Balancer Controller policy from upstream release v2.14.1."
  policy      = replace(
    file("${path.module}/aws-load-balancer-controller-iam-policy.json"),
    "arn:aws:",
    "arn:${data.aws_partition.current.partition}:",
  )
}

resource "aws_iam_role_policy_attachment" "load_balancer_controller" {
  role       = aws_iam_role.load_balancer_controller.name
  policy_arn = aws_iam_policy.load_balancer_controller.arn
}

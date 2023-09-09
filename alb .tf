####### ALB Ingress ######
locals {
  alb_namespace_name     = "alb-ingress"
  alb_controller_name    = "aws-load-balancer-controller"
  alb_controller_version = "v2.4.2"
}

### CRDS ###
data "http" "alb_crds" {
  url = "https://raw.githubusercontent.com/aws/eks-charts
  /master/stable/aws-load-balancer-controller/crds/crds.yaml"
  
  request_headers = {
    Accept = "application/yaml,text/plain"
  }
}

data "kubectl_file_documents" "alb_crds_yaml" {
  content = data.http.alb_crds.body
}

resource "kubectl_manifest" "alb_crds" {
  for_each  = data.kubectl_file_documents.alb_crds_yaml.manifests
  yaml_body = each.value
}


### iam ###
# Policy
data "http" "alb_iam" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-
  load-balancer-controller/${local.alb_controller_version}/docs/
  install/iam_policy.json"

  request_headers = {
    Accept = "application/yaml,text/plain"
  }
}

resource "aws_iam_policy" "alb_ingress" {
  name        = "${local.cluster_name}-alb-ingress"
  description = "Policy for alb-ingress service"

  policy = data.http.alb_iam.body
}


# Role
data "aws_iam_policy_document" "alb_ingress_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, 
      "https://", "")}:sub"

      values = [
        "system:serviceaccount:${local.alb_namespace_name}:
        ${local.alb_controller_name}",
      ]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "alb_ingress" {
  name               = "${local.cluster_name}-alb-ingress"
  assume_role_policy = data.aws_iam_policy_document.
  alb_ingress_assume.json
}

resource "aws_iam_role_policy_attachment" "alb_ingress" {
  role       = aws_iam_role.alb_ingress.name
  policy_arn = aws_iam_policy.alb_ingress.arn
}

resource "helm_release" "alb_ingress" {
  depends_on = [ kubectl_manifest.alb_crds ]

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"

  create_namespace = true
  namespace        = local.alb_namespace_name
  name             = local.alb_controller_name

  set {
    name  = "clusterName"
    value = local.cluster_name
  }

  set {
    name  = "image.repository"
    value = "602401143452.dkr.ecr.eu-central-1.amazonaws.com
    /amazon/aws-load-balancer-controller" //eu central repository
  }

  set {
    name  = "image.version"
    value = local.alb_controller_version
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.automountServiceAccountToken"
    value = "true"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.
    com/role-arn"
    value = aws_iam_role.alb_ingress.arn
  }

  set {
    name  = "rbac.create"
    value = "true"
  }

  set {
    name  = "replicaCount"
    value = "1"
  }
}

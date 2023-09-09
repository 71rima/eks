module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 18.20.5"

  cluster_name    = local.cluster_name
  cluster_version = "1.23"
  
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  subnet_ids = module.vpc.private_subnets
  vpc_id = module.vpc.vpc_id

  enable_irsa = true
  
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    ingress_cluster_all = {
      description                   = "Cluster to node all ports/protocols"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }


  eks_managed_node_group_defaults = {
    instance_types = ["t2.medium"]
    iam_role_additional_policies = [
      "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
      "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
      "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    ]
    disk_size = 50
    cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
    cluster_security_group_id = module.eks.node_security_group_id
  }
 
  eks_managed_node_groups = {
    bt_nodegroup = {
      min_size     = 1
      max_size     = 4
      desired_size = 2
      instance_types = ["t2.medium"]
    }
    
  }
  
  manage_aws_auth_configmap = true

  aws_auth_roles = [
    {
      rolearn  = "arn:aws:iam::409263333081:role/Admin"
      username = "Admin"
      groups   = ["system:masters"]
    },
    {
      rolearn  = "arn:aws:iam::930436893219:role/Admin"
      username = "admin"
      groups   = ["system:masters"]
    }
  ]
  aws_auth_users = [
    {
      rolearn  = "arn:aws:iam::409263333081:user/admin"
      username = "admin"
      groups   = ["system:masters"]
    },
    {
      rolearn  = "arn:aws:iam::409263333081:user/admin"
      username = "Admin/elsheami"
      groups   = ["system:masters"]
    }, 
    {
      rolearn  = "arn:aws:iam::409263333081:user/admin"
      username = "elsheami"
      groups   = ["system:masters"]
    },
  ]

  aws_auth_accounts = [
    "${var.account_id}"
  ]

}


data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}



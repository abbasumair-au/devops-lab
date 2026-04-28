terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.2"
    }
  }
}

provider "kind" {}

resource "kind_cluster" "lab" {
  name = "devops-lab"

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"
    }

    node {
      role = "worker"
    }
  }
}

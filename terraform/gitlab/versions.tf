terraform {
  required_version = ">= 1.11.6"

  required_providers {
    gitlab = {
      source = "gitlabhq/gitlab"
      version = "19.2.0"
    }
  }
}

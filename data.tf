data "terraform_remote_state" "s3" {
  backend = "s3"

  config = {
    bucket = "shared-terraform.joltdesign.joltrouter.net"
    key    = "network/terraform.tfstate"
    region = "eu-west-1"
  }
}

# WordPress

output "codebuild_project_name" {
  value = data.terraform_remote_state.s3.outputs.php_base_codebuild_project_name
}

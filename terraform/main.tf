module "vpc" {
  source = "./modules/vpc"

  project_id    = var.project_id
  region        = var.region
  name          = "${var.environment}-vpc"
  subnet_cidr   = var.vpc_subnet_cidr
  pods_cidr     = var.vpc_pods_cidr
  services_cidr = var.vpc_services_cidr
}

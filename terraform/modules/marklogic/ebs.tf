locals {
  ebs_volume_type = "gp3"
}

resource "aws_ebs_volume" "marklogic_data_volumes" {
  for_each = { for subnet in var.private_subnets : subnet.tags.Name => subnet }

  availability_zone = each.value.availability_zone
  size              = var.data_volume_size_gb
  encrypted         = true
  type              = local.ebs_volume_type
  iops              = 16000
  throughput        = 1000 # MiB/s - This argument is only valid for a volume of type gp3

  tags = {
    Name = "marklogic-ebs-data-volume-${each.value.availability_zone}-${var.environment}"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [tags, tags_all] # Updated by MarkLogic managed cluster
  }
}

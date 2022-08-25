# Create the Key Pair
resource "aws_key_pair" "ad_management_key_pair" {
  key_name   = "ad-management-key-pair"  
  public_key = var.ad_management_public_key
}

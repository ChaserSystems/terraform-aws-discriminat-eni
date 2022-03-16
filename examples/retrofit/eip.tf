resource "aws_eip" "nat_a" {
  tags = {
    "discriminat" : "some-comment"
  }

  lifecycle {
    prevent_destroy = false
  }
}

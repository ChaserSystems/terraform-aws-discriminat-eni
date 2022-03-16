resource "aws_eip" "nat_a" {
  tags = {
    "discriminat" : "some-comment"
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_eip" "nat_b" {
  tags = {
    "discriminat" : "any-remark"
  }

  lifecycle {
    prevent_destroy = false
  }
}

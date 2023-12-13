resource "aws_route53_zone" "env_signalhub_interop_pagopa_it" {
  name = "api.${var.environment}.signalhub.interop.pagopa.it"
}


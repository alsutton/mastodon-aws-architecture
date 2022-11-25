#
# Network configuration
#

resource "aws_vpc" "mastodon-vpc" {
    assign_generated_ipv6_cidr_block     = false
    enable_classiclink                   = false
    enable_classiclink_dns_support       = false
    enable_dns_hostnames                 = true
    enable_dns_support                   = true
    instance_tenancy                     = "default"
    tags                                 = {
        "Name" = "Mastodon VPC"
    }
    tags_all                             = {
        "Name" = "Mastodon VPC"
    }
}

resource "aws_subnet" "mastodon-subnet-0" {
  vpc_id                                = aws_vpc.mastodon-vpc.id
  cidr_block                            = "172.30.0.0/24"
  availability_zone                     = "eu-west-2a"
}

resource "aws_subnet" "mastodon-subnet-1" {
  vpc_id                                = aws_vpc.mastodon-vpc.id
  cidr_block                            = "172.30.1.0/24"
  availability_zone                     = "eu-west-2b"
}

resource "aws_subnet" "mastodon-subnet-2" {
  vpc_id                                = aws_vpc.mastodon-vpc.id
  cidr_block                            = "172.30.2.0/24"
  availability_zone                     = "eu-west-2c"
}

resource "aws_network_acl" "mastodon-acl" {
    vpc_id = aws_vpc.mastodon-vpc.id

    egress     = [
        {
            action          = "allow"
            cidr_block      = ""
            from_port       = 0
            icmp_code       = 0
            icmp_type       = 0
            ipv6_cidr_block = "::/0"
            protocol        = "-1"
            rule_no         = 101
            to_port         = 0
        },
        {
            action          = "allow"
            cidr_block      = "0.0.0.0/0"
            from_port       = 0
            icmp_code       = 0
            icmp_type       = 0
            ipv6_cidr_block = ""
            protocol        = "-1"
            rule_no         = 100
            to_port         = 0
        },
    ]
    ingress    = [
        {
            action          = "allow"
            cidr_block      = ""
            from_port       = 0
            icmp_code       = 0
            icmp_type       = 0
            ipv6_cidr_block = "::/0"
            protocol        = "-1"
            rule_no         = 110
            to_port         = 0
        },
        {
            action          = "allow"
            cidr_block      = "0.0.0.0/0"
            from_port       = 0
            icmp_code       = 0
            icmp_type       = 0
            ipv6_cidr_block = ""
            protocol        = "-1"
            rule_no         = 100
            to_port         = 0
        },
    ]
    subnet_ids = [
        aws_subnet.mastodon-subnet-0.id,
        aws_subnet.mastodon-subnet-1.id,
        aws_subnet.mastodon-subnet-2.id,
    ]
}

resource "aws_security_group" "mastodon-sg" {
    description = "Mastodon VPC Security Group"
    egress      = [
        {
            cidr_blocks      = [
                aws_vpc.mastodon-vpc.cidr_block,
            ]
            description      = ""
            from_port        = 0
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "-1"
            security_groups  = []
            self             = true
            to_port          = 0
        },
    ]
    ingress     = [
        {
            cidr_blocks      = [
                aws_vpc.mastodon-vpc.cidr_block,
            ]
            description      = ""
            from_port        = 0
            ipv6_cidr_blocks = []
            prefix_list_ids  = []
            protocol         = "-1"
            security_groups  = []
            self             = true
            to_port          = 0
        },
    ]
    vpc_id      = aws_vpc.mastodon-vpc.id
}
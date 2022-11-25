#
# Network security group configuration
#

# Security group for traffic inside the VPC

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

# Security group for reaching out to the internet

resource "aws_security_group" "outbound-internet-access-sg" {
    description = "Allow internet access for hosts"
    egress      = [
        {
            cidr_blocks      = [
                "0.0.0.0/0",
            ]
            description      = ""
            from_port        = 0
            ipv6_cidr_blocks = [
                "::/0",
            ]
            prefix_list_ids  = []
            protocol         = "-1"
            security_groups  = []
            self             = false
            to_port          = 0
        },
    ]
    vpc_id      = aws_vpc.mastodon-vpc.id
}

# Security group for accepting HTTP/HTTPS traffic from the web

resource "aws_security_group" "webserver-sg" {
    description = "Allows HTTP and HTTPS access from the internet"
    ingress     = [
        {
            cidr_blocks      = [
                "0.0.0.0/0",
            ]
            description      = ""
            from_port        = 443
            ipv6_cidr_blocks = [
                "::/0",
            ]
            prefix_list_ids  = []
            protocol         = "tcp"
            security_groups  = []
            self             = false
            to_port          = 443
        },
        {
            cidr_blocks      = [
                "0.0.0.0/0",
            ]
            description      = ""
            from_port        = 80
            ipv6_cidr_blocks = [
                "::/0",
            ]
            prefix_list_ids  = []
            protocol         = "tcp"
            security_groups  = []
            self             = false
            to_port          = 80
        },
    ]
    vpc_id      = aws_vpc.mastodon-vpc.id
}

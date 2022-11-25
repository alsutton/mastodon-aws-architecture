#
# EC2 configuration
#

# This should be the AMI which you have created for the
# scalable instances, which includes everything from a
# standard install except for processing the sidekiq
# scheduler queue.
resource "aws_ami" "configured-mastodon-web-ami" {
    name                = "mastodon-web-ami"
    architecture        = "arm64"
    description         = "Configured Mastodon Web AMI"
    ena_support         = true
    root_device_name    = "/dev/xvda"
    sriov_net_support   = "simple"
    virtualization_type = "hvm"

    ebs_block_device {
        delete_on_termination = true
        device_name           = "/dev/xvda"
        encrypted             = false
        iops                  = 3000
        throughput            = 125
        volume_size           = 8
        volume_type           = "gp3"
    }

    tags                 = {}
    tags_all             = {}
}

resource "aws_launch_template" "mastodon-lt" {
    disable_api_termination              = false
    ebs_optimized                        = "true"
    image_id                             = aws_ami.configured-mastodon-web-ami.id
    instance_initiated_shutdown_behavior = "terminate"
    instance_type                        = "t4g.small"

    capacity_reservation_specification {
        capacity_reservation_preference  = "open"
    }

    metadata_options {
        http_protocol_ipv6          = "disabled"
    }

    network_interfaces {
        associate_public_ip_address = "true"
        delete_on_termination       = "true"
        security_groups             = [
            aws_security_group.mastodon-sg.id,
            aws_security_group.outbound-internet-access-sg.id,
        ]
    }

    placement {
        tenancy           = "default"
    }

    tag_specifications {
        resource_type = "instance"
        tags          = {
            "Name" = "Mastodon"
        }
    }
}

resource "aws_lb" "mastodon-lb" {
    enable_cross_zone_load_balancing = true
    ip_address_type                  = "ipv4"

    security_groups                  = [
        aws_security_group.mastodon-sg.id,
        aws_security_group.webserver-sg.id,
        aws_security_group.outbound-internet-access-sg.id,
    ]

    subnets                         = [
        aws_subnet.mastodon-subnet-0.id,
        aws_subnet.mastodon-subnet-1.id,
        aws_subnet.mastodon-subnet-2.id
    ]
}

resource "aws_alb_target_group" "mastodon-tg" {
    port                          = 443
    protocol                      = "HTTPS"
     target_type                  = "instance"
    vpc_id                        = aws_vpc.mastodon-vpc.id

    health_check {
        matcher             = "200"
        path                = "/robots.txt"
        protocol            = "HTTPS"
    }

    stickiness {
        enabled         = false
        type            = "lb_cookie"
    }
}

resource "aws_autoscaling_group" "mastodon-asg" {
    min_size                  = 1
    desired_capacity          = 2
    max_size                  = 10

    default_cooldown          = 60
    health_check_grace_period = 30
    health_check_type         = "EC2"

    wait_for_capacity_timeout = "5m"

    target_group_arns         = [
        aws_alb_target_group.mastodon-tg.arn
    ]

    launch_template {
        id      = aws_launch_template.mastodon-lt.id
        version = "$Latest"
    }

    vpc_zone_identifier       = [
        aws_subnet.mastodon-subnet-0.id,
        aws_subnet.mastodon-subnet-1.id,
        aws_subnet.mastodon-subnet-2.id
    ]
}

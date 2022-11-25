#
# EC2 configuration
#

# This should be the AMI which you have created for
# scheduler queue processing, there can be only one of
# these, so we've treated it as a standalone instance
resource "aws_ami" "configured-mastodon-scheduler-ami" {
    name                = "mastodon-scheduler-ami"
    architecture        = "x86_64"
    description         = "Configured Mastodon Scheduler AMI"
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

resource "aws_launch_template" "mastodon-scheduler-lt" {
    disable_api_termination              = false
    ebs_optimized                        = "true"
    image_id                             = aws_ami.configured-mastodon-scheduler-ami.id
    instance_initiated_shutdown_behavior = "terminate"
    instance_type                        = "t3.micro"

    capacity_reservation_specification {
        capacity_reservation_preference  = "open"
    }

    metadata_options {
        http_endpoint               = "disabled"
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
            "Name" = "Mastodon Scheduler"
        }
    }
}

resource "aws_autoscaling_group" "mastodon-scheduler-asg" {
    min_size                  = 0
    desired_capacity          = 1
    max_size                  = 1

    default_cooldown          = 60
    health_check_grace_period = 30
    health_check_type         = "EC2"

    wait_for_capacity_timeout = "5m"

    launch_template {
        id      = aws_launch_template.mastodon-scheduler-lt.id
        version = "$Latest"
    }

    vpc_zone_identifier       = [
        aws_subnet.mastodon-subnet-0.id,
        aws_subnet.mastodon-subnet-1.id,
        aws_subnet.mastodon-subnet-2.id
    ]
}

#
# RDS Aurora Configuration
#

resource "aws_db_subnet_group" "mastodon-rds-subnet-group" {
    description = "Mastodon RDS Subnet Group"
    subnet_ids = [
        aws_subnet.mastodon-subnet-0.id,
        aws_subnet.mastodon-subnet-1.id,
        aws_subnet.mastodon-subnet-2.id,
    ]
}

resource "aws_rds_cluster_instance" "mastodon-writer" {
    auto_minor_version_upgrade            = true
    cluster_identifier                    = aws_rds_cluster.mastodon-cluster.id
    copy_tags_to_snapshot                 = false
    db_parameter_group_name               = "default.aurora-postgresql13"
    engine                                = "aurora-postgresql"
    engine_version                        = "13.7"
    identifier                            = "writer"
    instance_class                        = "db.t4g.medium"
    monitoring_interval                   = 0
    performance_insights_enabled          = false
    promotion_tier                        = 1
    publicly_accessible                   = false
}

resource "aws_rds_cluster" "mastodon-cluster" {
    backup_retention_period             = 7
    db_cluster_parameter_group_name     = "default.aurora-postgresql13"
    db_subnet_group_name                = aws_db_subnet_group.mastodon-rds-subnet-group.name
    deletion_protection                 = true
    enable_http_endpoint                = false
    engine                              = "aurora-postgresql"
    engine_version                      = "13.7"
    iam_database_authentication_enabled = false
    master_username                     = "postgres"
    vpc_security_group_ids              = [
        aws_security_group.mastodon-sg.id,
    ]
}
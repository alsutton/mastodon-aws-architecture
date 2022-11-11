terraform {
 required_providers {
   aws = {
     source  = "hashicorp/aws"
     version = "~> 3.0"
   }
 }
}

provider "aws" {
 region = "eu-west-2"
}

resource "aws_elasticache_parameter_group" "sidekiq-redis-parameter-group" {
    description = "Redis Parameter Group for a Sidekiq instance"
    family      = "redis6.x"
    name        = "sidekiq-redis-parameter-group"
    tags        = {}
    tags_all    = {}

    parameter {
        name  = "maxmemory-policy"
        value = "noeviction"
    }
}

resource "aws_elasticache_cluster" "mastodon-redis-001" {
    cluster_id               = "mastodon-redis-001"
    engine                   = "redis"
    engine_version           = "6.x"
    maintenance_window       = "sun:02:00-sun:04:00"
    node_type                = "cache.t4g.small"
    num_cache_nodes          = 1
    parameter_group_name     = "sidekiq-redis-parameter-group"
    port                     = 6379
    replication_group_id     = aws_elasticache_replication_group.mastodon-redis.id
    security_group_ids       = [
        "sg-0cd0ead115806618e",
    ]
    security_group_names     = []
    snapshot_retention_limit = 0
    snapshot_window          = "00:00-02:00"
    subnet_group_name        = "mastodon-redis-sg"
    tags                     = {}
    tags_all                 = {}
}

resource "aws_elasticache_cluster" "mastodon-redis-002" {
    cluster_id               = "mastodon-redis-002"
    engine                   = "redis"
    engine_version           = "6.x"
    maintenance_window       = "sun:02:00-sun:04:00"
    node_type                = "cache.t4g.small"
    num_cache_nodes          = 1
    parameter_group_name     = "sidekiq-redis-parameter-group"
    port                     = 6379
    replication_group_id     = aws_elasticache_replication_group.mastodon-redis.id
    security_group_ids       = [
        "sg-0cd0ead115806618e",
    ]
    security_group_names     = []
    snapshot_retention_limit = 7
    snapshot_window          = "00:00-02:00"
    subnet_group_name        = "mastodon-redis-sg"
    tags                     = {}
    tags_all                 = {}
}

resource "aws_elasticache_replication_group" "mastodon-redis" {
    auto_minor_version_upgrade    = true
    automatic_failover_enabled    = true
    data_tiering_enabled          = false
    engine                        = "redis"
    engine_version                = "6.x"
    maintenance_window            = "sun:02:00-sun:04:00"
    multi_az_enabled              = true
    node_type                     = "cache.t4g.small"
    number_cache_clusters         = 2
    parameter_group_name          = "sidekiq-redis-parameter-group"
    port                          = 6379
    replication_group_description = " "
    replication_group_id          = "mastodon-redis"
    security_group_ids            = [
        "sg-0cd0ead115806618e",
    ]
    security_group_names          = []
    snapshot_retention_limit      = 7
    snapshot_window               = "00:00-02:00"
    subnet_group_name             = "mastodon-redis-sg"
    tags                          = {}
    tags_all                      = {}
    transit_encryption_enabled    = false
    user_group_ids                = []

    cluster_mode {
        replicas_per_node_group = 1
    }
}

resource "aws_rds_cluster_instance" "writer" {
    auto_minor_version_upgrade            = true
    availability_zone                     = "eu-west-2a"
    ca_cert_identifier                    = "rds-ca-2019"
    cluster_identifier                    = "mastodon-cluster"
    copy_tags_to_snapshot                 = false
    db_parameter_group_name               = "default.aurora-postgresql13"
    engine                                = "aurora-postgresql"
    engine_version                        = "13.7"
    identifier                            = "writer"
    instance_class                        = "db.serverless"
    monitoring_interval                   = 0
    performance_insights_enabled          = false
    preferred_backup_window               = "22:09-22:39"
    preferred_maintenance_window          = "mon:05:18-mon:05:48"
    promotion_tier                        = 1
    publicly_accessible                   = false
}

resource "aws_rds_cluster" "default" {
    availability_zones                  = [
        "eu-west-2a",
        "eu-west-2b",
        "eu-west-2c",
    ]
    backtrack_window                    = 0
    backup_retention_period             = 7
    cluster_identifier                  = "mastodon-cluster"
    cluster_members                     = [
        "writer",
    ]
    copy_tags_to_snapshot               = true
    db_cluster_parameter_group_name     = "default.aurora-postgresql13"
    db_subnet_group_name                = "default-vpc-0c2459fe0a59c11ed"
    deletion_protection                 = false
    enable_http_endpoint                = false
    enabled_cloudwatch_logs_exports     = []
    engine                              = "aurora-postgresql"
    engine_mode                         = "provisioned"
    engine_version                      = "13.7"
    iam_database_authentication_enabled = false
    iam_roles                           = []
    master_username                     = "postgres"
    preferred_backup_window             = "22:09-22:39"
    preferred_maintenance_window        = "sun:01:32-sun:02:02"
    skip_final_snapshot                 = true
    vpc_security_group_ids              = [
        "sg-0cd0ead115806618e",
    ]
}
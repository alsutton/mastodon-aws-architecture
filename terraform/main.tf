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

    parameter {
        name  = "maxmemory-policy"
        value = "noeviction"
    }
}

resource "aws_elasticache_cluster" "mastodon-redis-001" {
    cluster_id               = "mastodon-redis-001"
    engine                   = "redis"
    engine_version           = "6.x"
    node_type                = "cache.t4g.small"
    num_cache_nodes          = 1
    parameter_group_name     = "sidekiq-redis-parameter-group"
    replication_group_id     = aws_elasticache_replication_group.mastodon-redis.id
    security_group_ids       = [
        "sg-0cd0ead115806618e",
    ]
    subnet_group_name        = "mastodon-redis-sg"
}

resource "aws_elasticache_cluster" "mastodon-redis-002" {
    cluster_id               = "mastodon-redis-002"
    engine                   = "redis"
    engine_version           = "6.x"
    node_type                = "cache.t4g.small"
    num_cache_nodes          = 1
    parameter_group_name     = "sidekiq-redis-parameter-group"
    replication_group_id     = aws_elasticache_replication_group.mastodon-redis.id
    security_group_ids       = [
        "sg-0cd0ead115806618e",
    ]
    subnet_group_name        = "mastodon-redis-sg"
}

resource "aws_elasticache_replication_group" "mastodon-redis" {
    auto_minor_version_upgrade    = true
    automatic_failover_enabled    = true
    data_tiering_enabled          = false
    engine                        = "redis"
    engine_version                = "6.x"
    multi_az_enabled              = true
    node_type                     = "cache.t4g.small"
    number_cache_clusters         = 2
    parameter_group_name          = "sidekiq-redis-parameter-group"
    replication_group_description = "Redis Replication Group for Mastodon"
    replication_group_id          = "mastodon-redis"
    security_group_ids            = [
        "sg-0cd0ead115806618e",
    ]
    security_group_names          = []
    subnet_group_name             = "mastodon-redis-sg"
    transit_encryption_enabled    = false

    cluster_mode {
        replicas_per_node_group = 1
    }
}

resource "aws_rds_cluster_instance" "mastodon-writer" {
    auto_minor_version_upgrade            = true
    cluster_identifier                    = "mastodon-cluster"
    copy_tags_to_snapshot                 = false
    db_parameter_group_name               = "default.aurora-postgresql13"
    engine                                = "aurora-postgresql"
    engine_version                        = "13.7"
    identifier                            = "writer"
    instance_class                        = "db.serverless"
    monitoring_interval                   = 0
    performance_insights_enabled          = false
    promotion_tier                        = 1
    publicly_accessible                   = false
}

resource "aws_rds_cluster" "mastodon-cluster" {
    cluster_identifier                  = "mastodon-cluster"
    cluster_members                     = [
        "mastodon-writer",
    ]
    db_cluster_parameter_group_name     = "default.aurora-postgresql13"
    db_subnet_group_name                = "default-vpc-0c2459fe0a59c11ed"
    deletion_protection                 = true
    enable_http_endpoint                = false
    engine                              = "aurora-postgresql"
    engine_version                      = "13.7"
    iam_database_authentication_enabled = false
    master_username                     = "postgres"
    vpc_security_group_ids              = [
        "sg-0cd0ead115806618e",
    ]
}
#
# Elasticache Redis configuration
#

resource "aws_elasticache_parameter_group" "sidekiq-redis-parameter-group" {
    description = "Redis Parameter Group for a Sidekiq instance"
    family      = "redis6.x"
    name        = "sidekiq-redis-parameter-group"

    parameter {
        name  = "maxmemory-policy"
        value = "noeviction"
    }
}

resource "aws_elasticache_subnet_group" "mastodon-elasticache-subnet-group" {
    description = "Mastodon Redis Subnet Group"
    name = "mastodon-redis-sg"
    subnet_ids = [
        aws_subnet.mastodon-subnet-0.id,
        aws_subnet.mastodon-subnet-1.id,
        aws_subnet.mastodon-subnet-2.id,
    ]
}

resource "aws_elasticache_replication_group" "mastodon-redis" {
    auto_minor_version_upgrade    = true
    automatic_failover_enabled    = false
    data_tiering_enabled          = false
    engine                        = "redis"
    engine_version                = "6.x"
    multi_az_enabled              = false
    node_type                     = "cache.t4g.small"
    number_cache_clusters         = 1
    parameter_group_name          = "sidekiq-redis-parameter-group"
    replication_group_description = "Redis Replication Group for Mastodon"
    replication_group_id          = "mastodon-redis"
    security_group_ids            = [
        aws_security_group.mastodon-sg.id,
    ]
    security_group_names          = []
    subnet_group_name             = aws_elasticache_subnet_group.mastodon-elasticache-subnet-group.name
    transit_encryption_enabled    = false

    cluster_mode {
        replicas_per_node_group = 0
    }
}

resource "aws_elasticache_cluster" "mastodon-redis-001" {
    cluster_id               = "mastodon-redis-001"
    replication_group_id     = aws_elasticache_replication_group.mastodon-redis.id
}
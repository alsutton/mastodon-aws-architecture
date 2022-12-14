# AWS Mastodon Architecture

## Disclaimer

This document is based on what we have running at [snapp.social](https://snapp.social). 
I don't claim to be an AWS mega-guru, but this seems a reasonably stable, resilient
installation that should serve most folk looking for something similar.

This setup is also not the cheapest way to get into Mastodon hosting. Folk like 
[Masto.Host](https://masto.host/) can offer you an easy, and inexpensive, way to
get a system up and running. You can, if you don't mind more work and possibly less
reliability, host your own on a VPS.

If you have improvement ideas for this document please submit a PR.

Open Action; [Create Terraform templates](https://github.com/alsutton/mastodon-aws-architecture/issues/1)

## Design

The design is a two-tier design with a load balancer in front of it. This design
was largely driven by Mastodons' ["Installing from source"](https://docs.joinmastodon.org/admin/install/)
document and splitting things out where there are break points called out.

Currently we're *not* using SES for email for this instance. You can use it, there is no
problem using it, but we have a corporate domain hosted on GMail, and so we use that for
sending to avoid non-Mastodon configuration issues with sending server verification.

I'm going to work from the back forwards so that folk can see how we built things up, so first
is the Data Storage Layer, then Application Layer, then exposing it to the Internet. 

## Data Storage Layer (Aurora, ElastiCache, S3)

We initially only used S3 for storage and seperated PostgreSQL out from each Masotdon instance, but then I found out that the
toots for the accounts users follow are stored in Redis. This meant that, because we're running multiple Masotdon EC2 
instances for the same domain, folk would sometimes get a varying toot list for their home page. It also meant
that when the EC2 instances were rolled for a configuration update, their whole home toot-list would be lost.
If this is acceptable to you (e.g. on your own instance and you're not worried about it), you could keep Redis in-instance.

### PostgreSQL - [Aurora Serverless v2 PostgreSQL](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.html) 

#### Initial Setup

This is an easy choice, Aurora Serverless V2 offers an "on-demand, autoscaling configuration for Amazon Aurora",
and Aurora offers supports PostgreSQL compatibility, so it was simple to use the Aurora instances configuration 
information.

#### Scaling-up

Aurora will scale pretty solidly, that's a core part of its' design.

Unfortunately Mastodon doesn't have native separation between Write and Read locations, 
[the recommendation](https://docs.joinmastodon.org/admin/scaling/#read-replicas) is to
use a special driver (Makara) to split reads and writes, but, with Aurora, that shouldn't
be necessary unless you're running a **really** big instance.

#### Current Instance Type

1x `Serverless v2 (0.5 - 5 ACUs)`

### Redis - [ElastiCache Redis in non-clustered mode](https://aws.amazon.com/elasticache/?nc=sn&loc=0)

#### Initial Setup

Initially I looked at [MemoryDB](https://aws.amazon.com/memorydb/), but [Sidekiq](https://sidekiq.org/), 
which is a core part of the Mastodon system, has [not recommended using Redis in cluster mode](https://github.com/mperham/sidekiq/issues/3454#issuecomment-405025735)
since problems were reported back in 2018. I did try a MemoryDB Redis instance, and an ElastiCache clustered instance, and hit 
the `CROSSSLOT` error mentioned in the bug, so we have to use a non-cluster configuration.

We also, initially, had a cluster consisting of a primary and read replica for our Redis instance to support fault tolerance. 
Clusters are, however, [not recommended by the Sidekiq creators](https://github.com/mperham/sidekiq/wiki/Using-Redis#architecture),
and we've seen reports of Sidekiq issues caused by latency between nodes creating an inconsistent state. With this in mind
we're now running a single Redis instance.

There's also a parameter to change from the defaults. In the ElastiCache console you'll need to create a new
parameter group and change the default value of `maxmemory-policy` from `volatile-lru` to `noeviction`. Using
the `noeviction` policy is a [recommendation from Sidekiqs' authors](https://github.com/mperham/sidekiq/wiki/Using-Redis#memory).


#### Scaling-up

ElastiCache will scale well beyond our needs by increasing the instance sizes, so that's our path for now.

#### Current Instance Type

1x `cache.t4g.small`

### S3

#### Initial Setup

To support multiple concurrent EC2 instances we would need a shared storage area, and Mastodon
includes S3 support, which made this a simple choice. The only part which was slightly confusing
was the question about serving through our own domain (the easiest answer is to say 'No'). 

One important point seems to be not to include a full-stop (`.`) in your bucket name. This seems
to cause confusion inside the app or in the AWS interface and makes media uploads fail. This is
not an AWS specific issue, I've seen the same problem with a GCP backed installation, so my
suspicion is it's a problem in the Mastodon codebase.

#### Scaling-up

Mastodon provide [a page](https://docs.joinmastodon.org/admin/optional/object-storage-proxy/) on 
a potential optimisation we've not deployed yet.

## Application Layer

At the application layer there is a very important thing to keep in mind; You should only
ever have one instance running the Sidekiq scheduler queue (see the bottom of [this
section of the scaling page](https://docs.joinmastodon.org/admin/scaling/#sidekiq)). This
means you can't take the standard Masotodon init scripts and use them in your AWS launch
template.

We're currently using `t4g.small` instances because they're cheap and can give us
small cost granularity in terms of supporting more users if we need to. 

### Sceduling instance - There can be only one

We run one instance solely to handle the `scheduler` queue. Initially we had a `t4g.small` 
instance processing all the queues (including scheduler), but, after looking at the load 
on the queues for a few days, we realised our main instances were easily handling the 
load on the queues, so the scheduler could be cost optimized. 

We now use a `t2.micro` instance which puts it in the 
[AWS EC2 free tier](https://aws.amazon.com/ec2/pricing/?loc=ft#Free_tier). We 
made the following modification to the `mastodon-sidekiq.service` init script, which
is the only mastodon init script enabled on that instance, to ensure it's only processing the
scheduler queue, and is running only 5 threads (which easily handles the load we have); 

```
ExecStart=/home/mastodon/.rbenv/shims/bundle exec sidekiq -c 25
```

becomes

```
ExecStart=/home/mastodon/.rbenv/shims/bundle exec sidekiq -c 5 -q scheduler
```

#### Current Instance Type

`t3.micro`

### Recent Changes

* 2022-11-23 : Called out issue with a Redis cluster.
* 2022-11-09 : Altered instance to focus only on the scheduler queue, which allows us to go from using a `t4g.small` to a `t2.micro`

### Main Instances

We have an EC2 Auto Scaling Group which uses the latest AMI for our installation. The
ASG is configured to scale upwards from a minimum & desired level of 2 instances (so that one can 
fall over unexpectedly and not affect service).

The launch template includes an auto-allocated public IP, which allows instances
to easily communicate with the world.

The AMIs follow the Mastodon ["Installing from source"](https://docs.joinmastodon.org/admin/install/)
page with *one very important change*. To ensure we only have one instance processing
the sidekiq `scheduler` queue, the init file `mastodon-sidekiq.service` has the
following change;

```
ExecStart=/home/mastodon/.rbenv/shims/bundle exec sidekiq -c 25
```

becomes

```
ExecStart=/home/mastodon/.rbenv/shims/bundle exec sidekiq -c 25 -q default -q push -q mailers -q pull
```

We also use a self-signed certificate to support HTTPS. Mastodon had the ability to run, 
in production, without an HTTPS configuration, [removed](https://github.com/mastodon/mastodon/pull/6061).
To avoid making our configuration more complex elsewhere, we use a self-signed cert
between the load balancer and the instances.

### Internet exposure

Each instance has an auto-assigned public IP. The reason for this is that the workers which
Sidekiq runs talk to other Mastodon instances, so we have configured all our instances with 
a public IP address. 

*We do not, however, expose services directly to the internet from them*. We use a 
[bastion host](https://en.wikipedia.org/wiki/Bastion_host) to connect to them via SSH,
and only expose the web services via an AWS [Application Load Balancer](https://aws.amazon.com/elasticloadbalancing/application-load-balancer/).

We have listeners on the ALB for HTTP and HTTPS. The HTTPS listener uses a publicly verifiable certificate 
issued by AWS, and both listeners forward to a separate Target Group which in turn
point to the relevant port on the Auto Scaling Group instances. One key point we found
was that the Target Group should monitor `/robots.txt` instead of `/` to ensure that 
it doesn't think an instance in unhealthy because it's returning a redirect for `/`.

#### Current Instance Type

2x `t4g.small` (Autoscaling hasn't gone past this)

## Summary

Hopefully this will help you get a resilient setup running, please submit [PRs](https://github.com/alsutton/mastodon-aws-architecture/pulls)
for things you think should be expanding on, or improved, so others can benefit from this page.

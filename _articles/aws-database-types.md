---
layout: post
title: "AWS Databases: How to Choose the Right One"
subtitle: "Eight data models, the AWS service built for each, and three questions that tell you which one your application needs."
date: 2026-11-27
author: Quan Huynh
tags: [aws, database, rds, aurora, dynamodb, architecture]
image: /assets/images/posts/aws-database-types/cover.svg
---

A team starts a new service and picks a database the usual way: PostgreSQL because that's what
they know, or DynamoDB because someone said it scales. Six months later they're fighting the
choice. Maybe they need joins that DynamoDB doesn't do, or a full-text search that PostgreSQL
does slowly at their size. Moving to another database by then means a migration project.

AWS runs more than ten managed database services. Each one is built for a *data model*: the
shape your data takes and the way you read it. So the choice is mostly a matter of matching
your data to a model, and the model to a service.

This post gives you three questions to ask about your application, then walks through the
eight data models on AWS and the answers that lead to each one. It ends with when one database
is enough and when a second one is worth running.

Facts and service names in this post come from AWS's
[database decision guide](https://docs.aws.amazon.com/decision-guides/latest/databases-on-aws-how-to-choose/databases-on-aws-how-to-choose.html),
last updated November 24, 2026.

## Three Questions Before You Pick

Answer these about your application, not about the database:

1. **What shape is the data?** Rows that reference each other (customers, orders, payments) are
   *relational*. Self-contained records you fetch whole (a user profile, a cart) are
   *documents* or *key-value* items. Data where the connections are the point (who knows whom)
   is a *graph*. Measurements stamped with a time (CPU usage, sensor readings) are a *time
   series*.
2. **How will you read it?** The ways your application reads data are its *access patterns*.
   Do you read by a known key ("get cart for user 42")? With queries you can't predict yet
   ("orders over $100 last week, by region")? By free text ("red running shoes")? By following
   relationships ("friends of friends")?
3. **What guarantees do you need?** If two writes must succeed or fail together (take payment
   *and* reduce stock), you need *ACID transactions*. ACID names four guarantees a database
   gives a transaction. The one that matters most here is that a transaction finishes
   completely or not at all, even when something fails halfway. Speed is the other guarantee
   to check: if answers must come back in microseconds, the data has to live in memory, not on
   disk.

Question 1 usually narrows the field to one or two models. Question 2 picks between them, and
question 3 rules out anything that can't give you the guarantee you need. Some models come
straight from questions 2 and 3: free-text reads point to search, and microsecond answers point
to in-memory.

![Three questions, what shape is the data, how will you read it, and what guarantees do you need, lead to one of eight data models, and each model maps to its AWS service: relational to RDS, Aurora, and Aurora DSQL; key-value to DynamoDB; document to DocumentDB; wide-column to Keyspaces; in-memory to ElastiCache and MemoryDB; search to OpenSearch Service; graph to Neptune; time series to Timestream for InfluxDB](/assets/images/posts/aws-database-types/choose-by-question.svg)

## The Map: Eight Data Models on AWS

| Data model | AWS service | Typical use | Poor fit |
| --- | --- | --- | --- |
| Relational | Amazon RDS, Amazon Aurora, Aurora DSQL | Orders, payments, anything with joins and transactions | Data with no fixed structure; extreme write scale on one instance |
| Key-value | Amazon DynamoDB | Sessions, carts, device state, lookups by key | Ad-hoc queries and joins |
| Document | Amazon DocumentDB (with MongoDB compatibility) | Product catalogs, profiles, content with nested fields | Data with many relationships between records |
| Wide-column | Amazon Keyspaces (for Apache Cassandra) | Heavy writes at high throughput, Cassandra migrations | Joins, queries that don't use the partition key |
| In-memory | Amazon ElastiCache, Amazon MemoryDB | Caches, leaderboards, rate limits, session stores | Large datasets that don't fit in memory affordably |
| Search | Amazon OpenSearch Service | Full-text search, log analytics, vector search | Your system of record for transactions |
| Graph | Amazon Neptune | Social networks, fraud detection, recommendations | Simple lookups that never follow relationships |
| Time series | Amazon Timestream for InfluxDB | Metrics, IoT readings, anything queried by time range | General-purpose application data |

The sections below take each model in turn: which answers lead to it, what the AWS service
does, and where the model causes problems.

## Relational: RDS, Aurora, and Aurora DSQL

A *relational database* stores data in tables with a fixed structure and links tables with keys.
You query it with SQL, and it supports transactions.

You land here when your data is rows that reference each other, when you can't list every
query yet, or when you need ACID transactions across several tables. That covers most business
applications, which is why relational is the usual default.

AWS gives you three ways to run one:

- **Amazon RDS** runs a standard engine for you: PostgreSQL, MySQL, MariaDB, SQL Server, Oracle,
  or Db2. AWS handles backups, patching, and failover to a standby in another Availability
  Zone (Multi-AZ). Choose it when you need a specific engine, version, or commercial database.
- **Amazon Aurora** is AWS's own MySQL- and PostgreSQL-compatible engine. It separates compute
  from a storage layer that AWS manages across Availability Zones. Choose it for new PostgreSQL
  or MySQL workloads that you expect to grow.
- **Amazon Aurora DSQL** is a serverless, distributed, PostgreSQL-compatible database. There
  are no instances to manage, and it can accept writes in more than one Region with strong
  consistency. It supports a subset of PostgreSQL, so check that the extensions and features
  you use are covered before you commit.

A common mistake is to assume relational means "doesn't scale" and pick something else up
front. A single Aurora cluster is enough for many applications. Move to another model when the
shape of the data or a real query demands it.

## Key-Value: DynamoDB

A *key-value database* stores items you read and write by a key, like a large distributed
dictionary. Amazon DynamoDB is serverless: you create a table and start writing, and AWS
advertises single-digit millisecond responses at any scale. It supports transactions across
items.

Question 2 decides whether DynamoDB fits. It works well when you can list your access patterns
before you design the table: "get cart by user ID", "list orders by customer, newest first".

The cost shows up when a new query arrives. DynamoDB has no joins, so a query you didn't plan
for usually means a new index or a second copy of the data. Teams that design a DynamoDB table
like a SQL table hit this early. If you can't list your access patterns yet, start relational.

## Document: DocumentDB

A *document database* stores records as JSON-like documents. Each document can have its own
nested fields, and you can query and index any field inside it. Amazon DocumentDB is
compatible with MongoDB, so MongoDB drivers and tools work with it.

Key-value and document data can look alike, since both are self-contained records. The
difference is in question 2. If you always fetch a record by its key, key-value is enough. If
you also need to query on fields inside the record, use a document database.

DocumentDB suits data whose shape changes from record to record: a product catalog where shoes
have sizes and laptops have CPUs, or user profiles with optional sections.

Be careful with data that is really relational. If you keep copying the same customer details
into many order documents to avoid joins, you'll end up keeping those copies in sync by hand.

## Wide-Column: Keyspaces

A *wide-column database* stores rows that can each have a different set of columns, spread
across many servers by a partition key. It's built for very high write throughput. Amazon
Keyspaces is a serverless service compatible with Apache Cassandra.

Use it to move an existing Cassandra workload to a managed service, or for write-heavy data
such as event logs and IoT readings that you read by partition.

Keyspaces is a narrow tool. If you're not coming from Cassandra and don't need its write
pattern, I'd reach for DynamoDB first; it's usually the simpler choice.

## In-Memory: ElastiCache and MemoryDB

An *in-memory database* keeps data in RAM, so reads come back in microseconds instead of
milliseconds. This is the answer when question 3 says speed matters more than anything else.
AWS has two services here, and the difference between them is durability:

- **Amazon ElastiCache** supports Valkey, Memcached, and Redis OSS. Its most common job is a
  *cache* in front of your main database: store the result of a slow query, and serve it from
  memory next time. It also handles session stores, leaderboards, rate limiting, and pub/sub.
- **Amazon MemoryDB** is a durable in-memory database for when the in-memory store *is* the
  source of truth, and it can accept writes in more than one Region. For a single Region, AWS
  notes that ElastiCache for Valkey with durability turned on also gives durable writes.

Without durability, a node restart can wipe the data. Treat a cache as a copy you can rebuild
from your main database, unless you chose one of the durable options.

## Search: OpenSearch Service

Amazon OpenSearch Service runs OpenSearch, the open-source fork of Elasticsearch. It indexes
text so you can search it by relevance ("red running shoes" also finds "running shoe, red"),
filter it, and aggregate it. It also handles log analytics and vector search.

You need it when question 2 includes free-text search. Run it next to your main database: the
application writes to the database, and a copy of the data goes to OpenSearch for searching.
DynamoDB, for example, can send data to OpenSearch through a zero-ETL integration.

Don't make OpenSearch the only copy of important data. A search index is built for finding
things, not for being the system of record.

## Graph: Neptune

A *graph database* stores items (*nodes*) and the connections between them (*edges*), and it's
fast at following connections many steps deep. Amazon Neptune supports the common graph query
languages, and Neptune Analytics adds graph analytics and vector similarity.

Use it when the relationships are the question: "friends of friends who like this page",
"accounts that share a device with a known fraudster", "products bought by people who bought
this".

By the way, a graph database has nothing to do with GraphQL. GraphQL is an API query language
and works with any database. A graph database is about how the data is stored.

## Time Series: Timestream

A *time-series database* stores values stamped with a time and is fast at queries over time
ranges: "average CPU per host, per minute, for the last hour". Amazon Timestream for InfluxDB
runs open-source InfluxDB as a managed service.

If your answer to question 1 was "measurements stamped with a time", this is the model. It
fits metrics, IoT sensor data, and monitoring, where you write a lot, rarely update, and read
by time window.

> **Note:** AWS shows an end-of-support notice for the older **Timestream for LiveAnalytics**
> and recommends Timestream for InfluxDB for similar workloads. Older articles, including the
> first version of this one, describe LiveAnalytics.

## What About Vector Search?

Generative AI applications store *embeddings*, lists of numbers that represent the meaning of
text or images, and search them by similarity. On AWS, vector search is built into services
you may already run: pgvector on Aurora and RDS for
PostgreSQL, OpenSearch Service, MemoryDB, DocumentDB, Neptune Analytics, and DynamoDB, plus
Amazon S3 Vectors for cheap storage at very large scale.

The practical rule from AWS's guide: start with the database your team already runs. If that's
PostgreSQL, try pgvector before adding anything new.

## One Application, Several Databases

Bigger applications often use more than one model, each for the part it fits. AWS's guide gives
an online store as the example:

- Aurora for orders and inventory, where transactions matter;
- DocumentDB for the product catalog and user profiles, which change shape often;
- DynamoDB for fast, predictable reads while people browse.

Run the three questions on each part of the store and you get the same split. I'd add
ElastiCache in front of a hot query, or OpenSearch for product search, only when measurements
show you need them.

![An online store uses each database for the part it fits: Aurora for orders and inventory, where transactions matter; DocumentDB for the product catalog and user profiles, which change shape often; DynamoDB for fast reads by key while people browse; and, optional and added only when measurements show a need, ElastiCache as a cache for hot queries and OpenSearch for product search](/assets/images/posts/aws-database-types/one-app-several-databases.svg)

Each extra database is another system to run, monitor, back up, secure, and keep in sync. The
AWS guide's advice for a solo developer or small team is to start with one database, such as
a single DynamoDB table or one Aurora DSQL cluster. Add a second only when a real query or a
real number shows the first can't do the job.

## Summary

- Pick a database by the shape of your data and how you read it, then check that it gives
  the guarantees you need.
- Relational (RDS, Aurora, Aurora DSQL) is the safe default when your queries aren't known yet
  or you need transactions.
- DynamoDB works well when you can list your access patterns up front, and gets painful when
  you can't.
- ElastiCache and OpenSearch usually sit next to your main database. Graph and time-series
  databases fit when relationships or time ranges are the main question.
- Start with one database and add another for a measured reason.

Next step: write down the five most important queries your application will run. Then check
which data model in the table above answers all five without workarounds.

## Resources

- [Choosing an AWS database service](https://docs.aws.amazon.com/decision-guides/latest/databases-on-aws-how-to-choose/databases-on-aws-how-to-choose.html), AWS decision guide
- [Databases on AWS](https://aws.amazon.com/products/databases/)
- [Amazon Aurora DSQL](https://aws.amazon.com/rds/aurora/dsql/)
- [Amazon ElastiCache](https://aws.amazon.com/elasticache/)
- [Amazon Timestream](https://aws.amazon.com/timestream/)

<!--
  ⚡ docker-compose-collection
  ZOLDYCK · TRANSMUTER · GODSPEED MODE
-->

<div align="center">

<img src="https://capsule-render.vercel.app/api?type=rect&height=36&color=0:020209,40:050d2e,60:050d2e,100:020209&text=%E2%9A%A1%20DOCKER+COMPOSE+COLLECTION%20%E2%9A%A1&fontSize=14&fontColor=00d4ff&fontAlignY=65" width="100%"/>

<br/>

<img src="https://readme-typing-svg.demolab.com?font=Orbitron&weight=900&size=32&duration=4000&pause=4000&color=00D4FF&center=true&vCenter=true&width=820&height=80&lines=DOCKER+COMPOSE+COLLECTION" alt="title"/>

<img src="https://readme-typing-svg.demolab.com?font=Share+Tech+Mono&size=15&duration=3000&pause=1000&color=4a9aba&center=true&vCenter=true&width=700&height=32&lines=%E2%9A%A1+Ready-to-use+Docker+Compose+templates+for+every+dev;%F0%9F%90%B9+Copy+%E2%80%A2+Configure+%E2%80%A2+Run+%E2%80%A2+Done" alt="subtitle"/>

<br/>

<img src="https://capsule-render.vercel.app/api?type=rect&height=2&color=0:020209,20:003d5c,50:00d4ff,80:003d5c,100:020209" width="75%"/>

<br/>

[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white&labelColor=0d2137)](https://docker.com)
[![Templates](https://img.shields.io/badge/Templates-12+-00d4ff?style=for-the-badge&labelColor=050d2e)](.)
[![License](https://img.shields.io/badge/License-MIT-00d4ff?style=for-the-badge&labelColor=050d2e)](LICENSE)

</div>

<br/>

<img src="https://capsule-render.vercel.app/api?type=rect&height=2&color=0:020209,20:003d5c,50:00d4ff,80:003d5c,100:020209" width="100%"/>

## ⚡ &nbsp;Available Templates

| Template | Services Included |
|----------|-------------------|
| `postgres` | PostgreSQL + pgAdmin |
| `mongodb` | MongoDB + Mongo Express |
| `redis` | Redis + Redis Commander |
| `mysql` | MySQL + phpMyAdmin |
| `elasticsearch` | Elasticsearch + Kibana |
| `kafka` | Kafka + Zookeeper + Kafka UI |
| `go-api` | Go API + PostgreSQL + Redis |
| `node-api` | Node.js API + PostgreSQL + Redis |
| `fullstack` | Frontend + Backend + DB + Nginx |
| `monitoring` | Prometheus + Grafana + Node Exporter |
| `logging` | Loki + Promtail + Grafana |
| `ci-runner` | GitLab Runner + Docker-in-Docker |

<img src="https://capsule-render.vercel.app/api?type=rect&height=2&color=0:020209,20:003d5c,50:00d4ff,80:003d5c,100:020209" width="100%"/>

## 🚀 &nbsp;Quick Start

```bash
git clone https://github.com/KhomkritTK/docker-compose-collection.git
cd docker-compose-collection

# Pick a template and run it
cd postgres
docker compose up -d

# PostgreSQL  → localhost:5432
# pgAdmin     → http://localhost:5050
```

<img src="https://capsule-render.vercel.app/api?type=rect&height=2&color=0:020209,20:003d5c,50:00d4ff,80:003d5c,100:020209" width="100%"/>

## 🗂️ &nbsp;Project Structure

```
docker-compose-collection/
├── postgres/
│   ├── docker-compose.yml
│   └── .env.example
├── mongodb/
│   ├── docker-compose.yml
│   └── .env.example
├── redis/
│   ├── docker-compose.yml
│   └── .env.example
├── go-api/
│   ├── docker-compose.yml
│   └── .env.example
├── fullstack/
│   ├── docker-compose.yml
│   ├── nginx.conf
│   └── .env.example
└── monitoring/
    ├── docker-compose.yml
    └── prometheus.yml
```

<img src="https://capsule-render.vercel.app/api?type=rect&height=2&color=0:020209,20:003d5c,50:00d4ff,80:003d5c,100:020209" width="100%"/>

## 📋 &nbsp;Template Details

### `postgres`
```yaml
services:
  postgres:
    image: postgres:16-alpine
    ports: ["5432:5432"]
  pgadmin:
    image: dpage/pgadmin4
    ports: ["5050:80"]
```

### `go-api`
```yaml
services:
  api:       # Go application
  postgres:  # Primary database
  redis:     # Cache + sessions
  nginx:     # Reverse proxy
```

### `monitoring`
```yaml
services:
  prometheus:     # Metrics collection
  grafana:        # Dashboard UI  → :3000
  node-exporter:  # Host metrics
```

<img src="https://capsule-render.vercel.app/api?type=rect&height=2&color=0:020209,20:003d5c,50:00d4ff,80:003d5c,100:020209" width="100%"/>

## 🧱 &nbsp;Tech Stack

<div align="center">

[![](https://skillicons.dev/icons?i=docker,postgres,mongodb,redis,nginx,grafana&theme=dark)](https://skillicons.dev)

</div>

<img src="https://capsule-render.vercel.app/api?type=rect&height=2&color=0:020209,20:003d5c,50:00d4ff,80:003d5c,100:020209" width="100%"/>

## 🤝 &nbsp;Contributing

Have a useful template? PRs welcome!

```bash
# Add a new template folder with:
# - docker-compose.yml
# - .env.example
# - README.md (optional, template-specific docs)
```

## 📄 &nbsp;License

Released under the [MIT License](LICENSE).

<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&height=120&color=0:020209,30:030e1c,60:041428,100:020209&section=footer" width="100%"/>

</div>

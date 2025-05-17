# Docker Deployment Guide for AptosSybilShield

This guide provides instructions for deploying the AptosSybilShield project using Docker and Docker Compose.

## Prerequisites

- Docker (version 20.10.0 or higher)
- Docker Compose (version 2.0.0 or higher)
- Git

## Quick Start

1. Clone the repository:

```bash
git clone https://github.com/yourusername/AptosSybilShield.git
cd AptosSybilShield
```

2. Start the services:

```bash
docker-compose up -d
```

This will start all services defined in the `docker-compose.yml` file:
- API Server (port 8000)
- ML Service
- Dashboard (port 3000)

3. Check the status of the services:

```bash
docker-compose ps
```

4. View logs:

```bash
docker-compose logs -f
```

## Service Details

### API Server

The API server provides RESTful endpoints for Sybil detection, identity verification, and analytics.

- **Port**: 8000
- **URL**: http://localhost:8000
- **Health Check**: http://localhost:8000/health

### Dashboard

The dashboard provides a web interface for monitoring and analytics.

- **Port**: 3000
- **URL**: http://localhost:3000

### ML Service

The ML service runs in the background and processes blockchain data for Sybil detection.

## Development with Docker

### Running Tests

```bash
docker-compose run --rm api test
```

### Compiling Move Modules

```bash
docker-compose run --rm move-compiler
```

### Accessing Shell

```bash
docker-compose run --rm api shell
```

## Configuration

### Environment Variables

You can customize the deployment by modifying the environment variables in the `docker-compose.yml` file:

- **API_PORT**: Port for the API server (default: 8000)
- **API_HOST**: Host for the API server (default: 0.0.0.0)
- **DATABASE_URL**: Database URL (default: sqlite:///data/aptos_sybil_shield.db)
- **LOG_LEVEL**: Logging level (default: INFO)

### Volumes

The following volumes are mounted:

- **./data**: Persistent data storage
- **./logs**: Log files

## Troubleshooting

### Services Not Starting

If services fail to start, check the logs:

```bash
docker-compose logs -f
```

### API Server Not Accessible

If the API server is not accessible, check if it's running:

```bash
docker-compose ps api
```

If it's running but not accessible, check the logs:

```bash
docker-compose logs api
```

### Database Issues

If you encounter database issues, you can reset the database:

```bash
docker-compose down
rm -rf data/aptos_sybil_shield.db
docker-compose up -d
```

## Production Deployment

For production deployment, consider the following:

1. Use a proper database instead of SQLite
2. Set up HTTPS with a reverse proxy (e.g., Nginx)
3. Implement proper authentication and authorization
4. Set up monitoring and alerting

## Cleanup

To stop and remove all containers:

```bash
docker-compose down
```

To stop and remove all containers, volumes, and images:

```bash
docker-compose down -v --rmi all
```

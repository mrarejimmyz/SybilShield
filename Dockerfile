# Dockerfile for AptosSybilShield (Devnet Version)

# Use multi-stage build for smaller final image
FROM python:3.11-slim as python-base

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    POETRY_VERSION=1.4.2 \
    POETRY_HOME="/opt/poetry" \
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    POETRY_NO_INTERACTION=1 \
    PYSETUP_PATH="/opt/pysetup" \
    VENV_PATH="/opt/pysetup/.venv"

ENV PATH="$POETRY_HOME/bin:$VENV_PATH/bin:$PATH"

# Install system dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    curl \
    build-essential \
    git \
    netcat-traditional \
    nodejs \
    npm \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Aptos CLI
RUN curl -fsSL "https://aptos.dev/scripts/install_cli.py" | python3

# Install Poetry
RUN curl -sSL https://install.python-poetry.org | python3 -

# Set up working directory
WORKDIR /app

# Copy project files
COPY . /app/

# Install Python dependencies
RUN pip install --upgrade pip \
    && pip install \
    requests \
    fastapi \
    uvicorn \
    pydantic \
    aptos-sdk \
    gql \
    pandas \
    numpy \
    networkx \
    scikit-learn \
    matplotlib \
    pytest

# Install Node.js dependencies for dashboard
RUN cd /app/dashboard/frontend && npm install

# Set up entrypoint
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Set default command
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["shell"]

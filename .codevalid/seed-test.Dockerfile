FROM postgres:16
# Postgres image ships psql; add curl, jq, ca-certificates, bash for test scripts
# (postgres skill SEED_CLIENT: FROM IMAGE ships psql + curl jq)
ARG CACHEBUST=1
RUN echo "cachebust=${CACHEBUST}" \
    && apt-get update && apt-get install -y --no-install-recommends \
        curl \
        jq \
        ca-certificates \
        bash \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
COPY seed_test_cases ./seed_test_cases
COPY tests ./tests

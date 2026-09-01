FROM node:20.19-slim

# Common tooling layer (§3.2)
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        bash \
        netcat-openbsd \
        jq \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Dependency install — manifest first for layer caching (§3.3)
# --ignore-scripts skips the postinstall prisma generate so we control timing (prisma skill)
# No lockfile committed (package-lock.json is gitignored); use npm install
COPY package.json ./
RUN npm install --ignore-scripts

# Copy all source including prisma schema, config, and migrations
COPY . .

# Prisma 7: generate AFTER COPY, BEFORE build (prisma skill BUILD order)
RUN npx prisma generate

# Compile TypeScript
RUN npm run build

ENV PORT=6713
EXPOSE 6713

COPY .codevalid/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["node", "dist/index.js"]

FROM oven/bun:1
WORKDIR /app

COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile

COPY . .

EXPOSE 8000

CMD ["sh", "-c", "bun db:push && bun index.ts"]

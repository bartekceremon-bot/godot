# --- Etap budowania (kompilacja TypeScript) ---
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
COPY test ./test
RUN npm run build

# --- Obraz uruchomieniowy ---
FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production \
    PORT=7171 \
    DB_PATH=/data/game.db
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /app/dist ./dist
VOLUME ["/data"]
EXPOSE 7171
CMD ["node", "--disable-warning=ExperimentalWarning", "dist/src/index.js"]

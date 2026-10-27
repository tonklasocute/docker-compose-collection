# syntax=docker/dockerfile:1

# Stages:
#   deps   npm ci with all dependencies (cached)
#   dev    `nest start --watch`; src/ is bind-mounted by compose (profile: dev)
#   test   typecheck + unit tests      (docker build --target test .)
#   build  compile to dist/, then drop devDependencies
#   prod   node + dist + production node_modules, non-root, no npm

FROM node:24.22.1-alpine3.24 AS base
ENV NPM_CONFIG_UPDATE_NOTIFIER=false NPM_CONFIG_FUND=false
RUN mkdir /app && chown node:node /app
WORKDIR /app
USER node

FROM base AS deps
COPY --chown=node:node package.json package-lock.json ./
RUN --mount=type=cache,target=/home/node/.npm,uid=1000,gid=1000 npm ci

FROM deps AS dev
ENV NODE_ENV=development
# Bind mounts on Docker Desktop don't deliver file events; make tsc poll
ENV TSC_WATCHFILE=DynamicPriorityPolling TSC_WATCHDIRECTORY=DynamicPriorityPolling
COPY --chown=node:node . .
EXPOSE 3000
CMD ["npm", "run", "start:dev"]

FROM deps AS test
COPY --chown=node:node . .
RUN npm run typecheck && npm test

FROM deps AS build
COPY --chown=node:node . .
RUN npm run build && npm prune --omit=dev

FROM node:24.22.1-alpine3.24 AS prod
ENV NODE_ENV=production
WORKDIR /app
# The app runs with plain `node`; npm, npx, corepack and yarn are dead weight
# (and attack surface) in a runtime image.
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/corepack \
      /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack \
      /usr/local/bin/yarn /usr/local/bin/yarnpkg /opt/yarn-*
# Files stay root-owned: the "node" user can run the app but not modify it
COPY --from=build /app/package.json ./
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
USER node
EXPOSE 3000
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
  CMD ["node", "-e", "fetch('http://127.0.0.1:3000/health').then(r => process.exit(r.ok ? 0 : 1), () => process.exit(1))"]
CMD ["node", "dist/main.js"]

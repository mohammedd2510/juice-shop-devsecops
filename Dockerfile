FROM node:24 AS installer
WORKDIR /juice-shop

# ── Dependency layer: cached until package.json or lockfile change ──
COPY package.json package-lock.json* ./
RUN npm install -g typescript ts-node && \
    npm install --omit=dev --unsafe-perm --ignore-scripts

# ── Source layer: invalidates on code change, but deps above stay cached ──
COPY . .

# Now run the postinstall that was skipped above — it needs source files
RUN npm run postinstall

# Cleanup + SBOM
RUN npm dedupe --omit=dev && \
    rm -rf frontend/node_modules frontend/.angular frontend/src/assets && \
    mkdir -p logs && \
    chown -R 65532 logs && \
    chgrp -R 0 ftp/ frontend/dist/ logs/ data/ i18n/ && \
    chmod -R g=u ftp/ frontend/dist/ logs/ data/ i18n/ && \
    rm -f data/chatbot/botDefaultTrainingData.json ftp/legal.md i18n/*.json

ARG CYCLONEDX_NPM_VERSION='^2.0.0||^3.0.0||^4.0.0'
RUN npm install -g @cyclonedx/cyclonedx-npm@$CYCLONEDX_NPM_VERSION && \
    npm run sbom

FROM gcr.io/distroless/nodejs24-debian13
ARG BUILD_DATE
ARG VCS_REF
LABEL maintainer="Bjoern Kimminich <bjoern.kimminich@owasp.org>" \
      org.opencontainers.image.title="OWASP Juice Shop" \
      org.opencontainers.image.version="19.2.1" \
      org.opencontainers.image.source="https://github.com/juice-shop/juice-shop"
WORKDIR /juice-shop
COPY --from=installer --chown=65532:0 /juice-shop .
USER 65532
EXPOSE 3000
CMD ["/juice-shop/build/app.js"]
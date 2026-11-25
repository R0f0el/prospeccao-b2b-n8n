FROM n8nio/n8n:latest

ENV GENERIC_TIMEZONE=America/Sao_Paulo \
    TZ=America/Sao_Paulo \
    N8N_PROTOCOL=https \
    N8N_DIAGNOSTICS_ENABLED=false \
    N8N_RUNNERS_ENABLED=true \
    N8N_BLOCK_ENV_ACCESS_IN_NODE=false

EXPOSE 5678

# O Render injeta $PORT; localmente usa 5678
ENTRYPOINT ["/bin/sh", "-c", "export N8N_PORT=${PORT:-5678} && exec n8n start"]

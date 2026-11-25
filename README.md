# Prospecção B2B — Estabelecimentos Sem Site

Automação em **n8n** que identifica estabelecimentos comerciais locais sem website (via OpenStreetMap/Overpass), deduplica com **Upstash Redis** e persiste os leads qualificados no **Neon PostgreSQL** — com custo zero de infraestrutura.

## Arquitetura

```text
[cron-job.org] --GET /webhook/prospectar?cidade=...--> [Render: n8n] <--> [Neon PostgreSQL]
                                                          |--> [Upstash Redis] (cache + dedup)
                                                          '--> [Overpass API]
```

## Estrutura

| Caminho | Conteúdo |
|---|---|
| `Dockerfile` | Imagem n8n com porta dinâmica e fuso `America/Sao_Paulo` |
| `render.yaml` | Blueprint do Web Service no Render |
| `.env.example` | Variáveis de ambiente necessárias |
| `sql/leads_sem_site.sql` | DDL da tabela de leads |
| `workflows/prospeccao.json` | Workflow n8n para importação |

## Deploy

### Fase 1 — Dados e cache
1. Crie um banco no [Neon.tech](https://neon.tech) e execute `sql/leads_sem_site.sql`.
2. Crie um banco Redis no [Upstash](https://upstash.com) e anote host, porta e senha.

### Fase 2 — Aplicação
1. No [Render](https://render.com), crie um **Web Service** apontando para este repositório (runtime Docker) ou use o `render.yaml`.
2. Preencha as variáveis listadas em `.env.example`.

### Fase 3 — Workflow e agendamento
1. Acesse o n8n e importe `workflows/prospeccao.json`.
2. Configure as credenciais **Redis** (Upstash, com TLS) e **Postgres** (Neon, com SSL), com os nomes `Upstash Redis` e `Neon Postgres`.
3. Ative o workflow e cadastre no [cron-job.org](https://cron-job.org):
   `https://SEU-APP.onrender.com/webhook/prospectar?cidade=São Paulo`

## Fluxo

1. Webhook recebe `cidade`.
2. `GET cache:busca:{cidade}` — se existir, encerra.
3. Overpass QL busca estabelecimentos sem `website`/`contact:website`.
4. Filtra registros sem nome ou telefone.
5. `SISMEMBER leads:processados` descarta `osm_id` já vistos.
6. Normaliza telefone (`55` + DDD + número), gera link do WhatsApp e endereço.
7. `INSERT ... ON CONFLICT (osm_id) DO NOTHING` em `leads_sem_site`.
8. `SADD leads:processados` e `SETEX cache:busca:{cidade}` (7 dias).

# Prospecção B2B — Estabelecimentos Sem Site

Fluxo **n8n** que busca no OpenStreetMap comércios **sem website e com telefone**, gera link de WhatsApp e salva os leads no PostgreSQL. Roda 100% em planos gratuitos.

> **Status:** em testes — ainda não validado em produção.

## Como funciona

```text
cron-job.org ──GET /webhook/prospectar?cidade=X──► n8n (Render)
                                                    ├─► Upstash Redis  (cache 7 dias + IDs já vistos)
                                                    ├─► Overpass API   (dados OSM, sem chave)
                                                    └─► Neon Postgres  (tabela leads_sem_site)
```

Cidade buscada nos últimos 7 dias → ignora. Senão: consulta Overpass → filtra sem nome/telefone → descarta IDs já salvos → normaliza telefone (`55`+DDD+número) → grava.

## Pré-requisitos

Contas gratuitas: [Neon](https://neon.tech) · [Upstash](https://upstash.com) · [Render](https://render.com) · [cron-job.org](https://cron-job.org). Para rodar local: Docker.

## Instalação

**1. Banco** — no Neon, crie um projeto e rode [`sql/leads_sem_site.sql`](sql/leads_sem_site.sql) no SQL Editor.

**2. Redis** — no Upstash, crie um banco Redis. Anote host, porta e senha.

**3. n8n no Render** — faça fork deste repo → Render → **New › Blueprint** → selecione o fork (usa [`render.yaml`](render.yaml)). Preencha:

| Variável | Valor |
|---|---|
| `DB_POSTGRESDB_HOST` / `_DATABASE` / `_USER` / `_PASSWORD` | dados de conexão do Neon |
| `N8N_HOST` | `seu-app.onrender.com` |
| `WEBHOOK_URL` | `https://seu-app.onrender.com/` |

`N8N_ENCRYPTION_KEY` é gerada sozinha — **não troque depois**, ou as credenciais salvas no n8n quebram.

**4. Workflow** — abra o n8n, crie o usuário dono e:
- Crie credenciais com estes nomes exatos: `Upstash Redis` (SSL ligado) e `Neon Postgres` (SSL ligado).
- **Workflows › Import from file** → [`workflows/prospeccao.json`](workflows/prospeccao.json) → **Activate**.

**5. Agendamento** — no cron-job.org, crie um job para:
```
https://seu-app.onrender.com/webhook/prospectar?cidade=Curitiba
```
Timeout ≥ 2 min (o Render gratuito leva ~1 min para acordar).

## Rodar local

```bash
cp .env.example .env   # preencha
docker build -t prospeccao .
docker run --env-file .env -p 5678:5678 prospeccao
```
Acesse `http://localhost:5678`. Para testes rápidos, pode remover as variáveis `DB_*` — o n8n usa SQLite interno.

## Consultar leads

```sql
SELECT nome, telefone, whatsapp_link, endereco
FROM leads_sem_site
WHERE cidade = 'Curitiba' AND status_prospeccao = 'NOVO';
```
Status possíveis: `NOVO`, `CONTATADO`, `NEGOCIANDO`, `DESCARTADO`.

## Limitações

- O nome da cidade precisa bater com o do OSM; nomes repetidos em estados diferentes podem misturar resultados.
- A Overpass pública tem limite de uso — evite muitas cidades por minuto.
- Os dados do OSM são colaborativos: telefones podem estar desatualizados.
- Render gratuito hiberna após 15 min sem acesso.

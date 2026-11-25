# Prospecção B2B — Estabelecimentos Sem Site

Fluxo **n8n** que busca no OpenStreetMap comércios **sem website e com telefone**, gera link de WhatsApp e salva os leads no PostgreSQL. Roda 100% em planos gratuitos.

> **Status:** em testes — ainda não validado em produção.

## Como funciona

```text
cron-job.org ──GET /webhook/prospectar?cidade=X&uf=YY──► n8n (Render)
                                                          ├─► Upstash Redis  (cache 7 dias + IDs já vistos)
                                                          ├─► Overpass API   (dados OSM, sem chave)
                                                          └─► Neon Postgres  (tabela leads_sem_site)
```

Cidade buscada nos últimos 7 dias → ignora. Senão: consulta Overpass → filtra sem nome/telefone → normaliza telefone (`55`+DDD+número) → descarta IDs já salvos → grava.

O webhook responde na hora (`200`); o processamento segue em segundo plano. Veja o resultado em **Executions** no n8n.

## Pré-requisitos

Contas gratuitas: [Neon](https://neon.tech) · [Upstash](https://upstash.com) · [Render](https://render.com) · [cron-job.org](https://cron-job.org). Para rodar local: Docker.

## Instalação

**1. Banco** — no Neon, crie um projeto e rode [`sql/leads_sem_site.sql`](sql/leads_sem_site.sql) no SQL Editor.

**2. Redis** — no Upstash, crie um banco Redis. Na aba **REST API**, copie `UPSTASH_REDIS_REST_URL` e `UPSTASH_REDIS_REST_TOKEN`.

**3. n8n no Render** — faça fork deste repo → Render → **New › Blueprint** → selecione o fork (usa [`render.yaml`](render.yaml)). Preencha:

| Variável | Valor |
|---|---|
| `DB_POSTGRESDB_HOST` / `_DATABASE` / `_USER` / `_PASSWORD` | dados de conexão do Neon |
| `N8N_HOST` | `seu-app.onrender.com` |
| `WEBHOOK_URL` | `https://seu-app.onrender.com/` |
| `UPSTASH_REDIS_REST_URL` / `_TOKEN` | dados da aba REST API do Upstash |

`N8N_ENCRYPTION_KEY` é gerada sozinha — **não troque depois**, ou as credenciais salvas no n8n quebram.

**4. Workflow** — abra o n8n, crie o usuário dono e:
- Crie uma credencial **Postgres** com o nome exato `Neon Postgres` (SSL: *require*). O Redis não precisa de credencial — usa as variáveis acima.
- **Workflows › Import from file** → [`workflows/prospeccao.json`](workflows/prospeccao.json) → **Activate**.

**5. Agendamento** — no cron-job.org, crie um job para:
```
https://seu-app.onrender.com/webhook/prospectar?cidade=Curitiba&uf=PR
```
`cidade` obrigatório (nome igual ao do OpenStreetMap, com acento). `uf` opcional, mas recomendado.
Timeout ≥ 1 min (o Render gratuito leva ~1 min para acordar).

## Rodar local

```bash
cp .env.example .env   # preencha
docker build -t prospeccao .
docker run --env-file .env -p 5678:5678 prospeccao
```
Acesse `http://localhost:5678`. Para testes rápidos, pode remover as variáveis `DB_*` do n8n — ele usa SQLite interno (a credencial `Neon Postgres` continua necessária para gravar os leads).

## Consultar leads

```sql
SELECT nome, telefone, whatsapp_link, endereco
FROM leads_sem_site
WHERE cidade = 'Curitiba' AND status_prospeccao = 'NOVO';
```
Status possíveis: `NOVO`, `CONTATADO`, `NEGOCIANDO`, `DESCARTADO`.

## Limitações

- O nome da cidade precisa bater com o do OSM. Sem `uf`, cidades homônimas em outros estados entram juntas.
- A Overpass pública tem limite de uso — evite muitas cidades por minuto. Capitais grandes podem estourar o timeout.
- Os dados do OSM são colaborativos: telefones podem estar desatualizados.
- Render gratuito hiberna após 15 min sem acesso.
- `osm_id` guarda tipo + ID (`node/123`), pois IDs de tipos diferentes podem se repetir no OSM.

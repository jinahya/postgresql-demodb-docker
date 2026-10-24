# postgresql-demodb-docker

Docker images of the official [`postgres`](https://hub.docker.com/_/postgres) image with the
[Postgres Professional demo database (Airlines)](https://postgrespro.com/community/demodb) loaded on first start.

Images are published to:

- Docker Hub: [`onacit/postgresql-demodb`](https://hub.docker.com/r/onacit/postgresql-demodb)
- GitHub Container Registry: [`ghcr.io/jinahya/postgresql-demodb`](https://github.com/jinahya/postgresql-demodb-docker/pkgs/container/postgresql-demodb)

## Quick start

```sh
docker run -d --name demodb -p 5432:5432 -e POSTGRES_PASSWORD=secret onacit/postgresql-demodb:18
# wait for the first-start load to finish, then
psql -h localhost -U postgres -d demo -c 'select count(*) from bookings.flights'
```

The database is named `demo`, schema `bookings`, and the search path is preset so `select * from flights` works.
Everything else (`POSTGRES_PASSWORD`, `POSTGRES_USER`, volumes, config) behaves exactly like the official image.

## Tags

Tags mirror the official `postgres` tags, followed by the demo database release and dataset size:

```
<postgres tag>-<dataset>-<size>        e.g. 18-trixie-20250901-3m, 18.6-alpine-20250901-2y
```

Shorthand tags drop a component and follow the newest release of what they omit:

| omitted part | meaning | example |
|---|---|---|
| dataset | newest demo database release | `18-3m`, `18-alpine-2y` |
| size | the default size, `3m` | `18-20250901`, `bookworm-20250901` |
| both | newest release, default size | `18`, `18.6-trixie`, `alpine`, `latest` |

So every official tag such as `postgres:18-alpine` has a counterpart `onacit/postgresql-demodb:18-alpine` that carries the
newest 3-month dataset. Pin the full tag, e.g. `18.6-trixie-20250901-3m`, when you need an image that never changes.

### Dataset sizes

| size | data span | download in image | database after load | first start (CI runner, SSD) |
|---|---|---|---|---|
| `3m` | 3 months | ~140 MB | ~1.3 GB | ~1 min |
| `6m` | 6 months | ~290 MB | ~2.7 GB | ~2–3 min |
| `1y` | 1 year | ~590 MB | ~5.4 GB | ~3–4 min |
| `2y` | 2 years | ~1.2 GB | ~11 GB | ~7–10 min |

### Dataset releases

| release | PostgreSQL | sizes |
|---|---|---|
| `20250901` | 18 | `3m`, `6m`, `1y`, `2y` |

## How it works

The image only adds the gzipped SQL dump and a small init script to the official image. On the first start of an empty
data directory the official entrypoint runs the script, which creates the `demo` database and replays the dump with
`psql`, exactly as the demodb page describes. Later starts skip the load, so keep the data volume to avoid reloading.
The port opens only after the load has finished; wait for it with `pg_isready` or a health check.

## Environment

| variable | default | description |
|---|---|---|
| `DEMODB_LANG` | `en` | sets `bookings.lang` for the demo database at load time; use `ru` for Russian names |

All variables of the official image apply as well.

## Building locally

```sh
scripts/fetch-dump.sh 20250901 3m          # downloads ./dumps/demo-20250901-3m.sql.gz and verifies it
docker build -t postgresql-demodb:18-3m \
  --build-arg BASE_IMAGE=postgres:18 --build-arg DEMODB_VERSION=20250901 --build-arg DEMODB_SIZE=3m .
scripts/smoke-test.sh postgresql-demodb:18-3m
```

## Maintenance

- `versions.json` lists the dataset releases, their sha256 checksums, and the PostgreSQL majors to build.
- `scripts/matrix.py` asks Docker Hub for the current `postgres` tags of those majors and generates the build matrix and
  tag lists. It only builds base variants that carry the latest minor release.
- A second workflow syncs this README to the Docker Hub repository description whenever it changes.
- The GitHub Actions workflow builds every entry for `linux/amd64` and `linux/arm64`, smoke tests it by loading the data,
  and pushes to GHCR and Docker Hub. It runs on pushes, weekly to follow new PostgreSQL minor releases, and on demand.
- To add a dataset release or a PostgreSQL major, edit `versions.json`.

## License

The demo database is © Postgres Professional and distributed under the MIT license (see the header of the dump).
The files in this repository are MIT licensed as well.

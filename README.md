# Docker image blueprint for Symfony development

To simply update the running Symfony application run 

```bash
./deploy.sh main/prod
```

in the main directory.

Download:

```bash
git clone https://juergenarne@github.com/juergenarne/symfony-docker-blueprint.git .
```

Tweak:

Create your `.env` from the template and fill in real values (passwords!):

```bash
cp .env.dist .env
```

The `.env` is not in git. On a server with an existing database, its `MYSQL_*` values must match that database -
MariaDB only reads them when its data directory is still empty.

Run:

```bash
docker compose up -d --build
```

Check:

``````bash
docker compose ps
docker compose logs -f
``````

Optionally you can use the included start script:

```bash
./start.sh
```

To clone your repo into the  `symfony`  directory:

```bash
./install.sh
```

Open: <http://localhost:8085/> and start coding.

To update the code:

```bash
./deploy.sh
```

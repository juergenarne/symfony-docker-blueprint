# Docker image blueprint for Symfony development

Download:

```bash
git clone https://juergenarne@github.com/juergenarne/symfony-docker-blueprint.git
```

Tweak:

Modify stuff from the .env file and from the msmtprc file to meet your needs.

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





Open: http://localhost:8085/ and start coding.
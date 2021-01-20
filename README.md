# axiom-demo [![Build](https://github.com/axiomhq/axiom-demo/workflows/Build/badge.svg)](https://github.com/axiomhq/axiom-demo/actions?query=workflow%3ABuild)

This repo contains a ready-to-go demo to try Axiom locally.

## Get started

This requires [Docker] and [docker-compose] to be installed:

```sh
git clone https://github.com/axiomhq/axiom-demo.git
cd axiom-demo
docker-compose up -d
```

Open your browser to [:8080](http://localhost:8080) and log in with these 
credentials: 

Email: `demo@axiom.co`  
Password: `axiom-d3m0`

## Stopping the stack

Run `docker-compose stop` to stop the stack, `docker-compose start` to start
it again.

If you want to clean up, run `docker-compose down -v` to remove all containers 
and volumes. The docker images will persist on your machine unless you manually
delete them.

[Docker]: https://docs.docker.com/engine/install/
[docker-compose]: https://docs.docker.com/compose/install/

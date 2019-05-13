#! /bin/bash

docker exec -i $(docker ps -qf "label=io.kubernetes.pod.name=harbor-harbor-database-0" -f "label=io.kubernetes.container.name=database") -U postgres < clear.sql
docker exec -i $(docker ps -qf "label=io.kubernetes.pod.name=harbor-harbor-database-0" -f "label=io.kubernetes.container.name=database") -U postgres < vulnerability.sql

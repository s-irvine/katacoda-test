#! /bin/bash

docker exec -i $(docker ps -qf "label=io.kubernetes.pod.name=harbor-harbor-database-0" -f "label=io.kubernetes.container.name=database") psql -U postgres < clear.sql > /dev/null
echo "Deployed First DB"
docker exec -i $(docker ps -qf "label=io.kubernetes.pod.name=harbor-harbor-database-0" -f "label=io.kubernetes.container.name=database") psql -U postgres < vulnerability.sql > /dev/null
echo "Deployed Second DB"
echo "Done"

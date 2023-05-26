#!/usr/bin/env bash

# Enable debug (xtrace) mode. When enabled, the shell will display each command it executes along with its expanded arguments. 
set -x

# -e is `errexit`, or "exit immediately on error".
# -o pipefail sets the "pipefail" option, which ensures that the return value of a pipeline is the value of the last (rightmost) command to exit with a non-zero status. By default, in a pipeline of commands separated by the | symbol, only the exit status of the last command in the pipeline is considered. However, with pipefail, if any command in the pipeline fails (exits with a non-zero status), the entire pipeline is considered to have failed.
#
# The combination of these options (-e and pipefail) is particularly useful in scripts to ensure that errors are caught immediately and the script's execution is halted if any command fails. It helps in writing more robust and reliable scripts.
set -eo pipefail

# Check if custom credentials have been set, otherwise default to right of :=
DB_USER="${POSTGRES_USER:=postgres}"
DB_PASSWORD="${POSTGRES_PASSWORD:=password}"
DB_NAME="${POSTGRES_DB:=newsletter}"
DB_PORT="${POSTGRES_PORT:=5069}"
DB_HOST="${POSTGRES_HOST:=localhost}"
CONTAINER_NAME="rust-newsletter-db"

# Ensure Container is started from scratch so script doesn't fail.
docker stop ${CONTAINER_NAME}
docker rm ${CONTAINER_NAME}

# Launch Postgres via Docker
docker run \
        --name ${CONTAINER_NAME} \
        -e POSTGRES_USER=${DB_USER} \
        -e POSTGRES_PASSWORD=${DB_PASSWORD} \
        -e POSTGRES_DB=${DB_NAME} \
        -p "${DB_PORT}":5432 \
        -d postgres \
        postgres -N 1000 # Increase max number of concurrent connections for testing

# An entry like 0.0.0.0:5069->5069/tcp, 5432/tcp in the "PORTS" column of the `docker ps --all` output indicates two port mappings for the container.
#
# 0.0.0.0:5069->5069/tcp: This means that port 5069 inside the container is being mapped to port 5069 on the host system using the TCP protocol. The IP address 0.0.0.0 in this context represents all available network interfaces on the host system. So, any incoming requests on port 5069 of the host system will be forwarded to the container.
#
# 5432/tcp: This entry indicates that port 5432 inside the container is exposed, but it is not explicitly mapped to a port on the host system. In this case, the container's service on port 5432 is only accessible from within the container itself or from other containers in the same Docker network. To access this service from the host system or external network, you would need to establish some additional network configuration, such as using Docker's network features or container linking.
#
# Overall, with the given entry, you can access the service running on port 5069 of the container by using localhost:5069 or <host-ip>:5069 on your host system. However, to access the service on port 5432, you would need to consider additional networking configurations.

until docker inspect -f {{.State.Running}} ${CONTAINER_NAME}; do
  >&2 echo "Postgres service ${CONTAINER_NAME} is still unavailable -- sleeping "
  sleep 1
done
>&2 echo "Postgres service ${CONTAINER_NAME} is now up and running on port ${DB_PORT}!"

# Export the DATABASE_URL from `sqlx create database --help`
# See https://www.postgresql.org/docs/15/libpq-connect.html for connection format
export DATABASE_URL=postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}
sqlx database create

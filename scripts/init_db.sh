#!/usr/bin/env bash

# Enable debug (xtrace) mode. When enabled, the shell will display each command it executes along with its expanded arguments.
set -x

# -e is `errexit`, or "exit immediately on error".
# -o pipefail sets the "pipefail" option, which ensures that the return value of a pipeline is the value of the last (rightmost) command to exit with a non-zero status. By default, in a pipeline of commands separated by the | symbol, only the exit status of the last command in the pipeline is considered. However, with pipefail, if any command in the pipeline fails (exits with a non-zero status), the entire pipeline is considered to have failed.
#
# The combination of these options (-e and pipefail) is particularly useful in scripts to ensure that errors are caught immediately and the script's execution is halted if any command fails. It helps in writing more robust and reliable scripts.
set -eo pipefail

if ! [ -x "$(command -v psql)" ]; then
	echo >&2 "Error: psql is not installed."
	exit 1
fi

if ! [ -x "$(command -v sqlx)" ]; then
	echo >&2 "Error: sqlx is not installed."
	echo >&2 "Use: cargo install --version='~0.6' sqlx-cli --no-default-features --features rustls, postgres"
	echo >&2 "to install it."
	exit 1
fi

# Check if custom credentials have been set, otherwise default to right of :=
DB_USER="${POSTGRES_USER:=postgres}"
DB_PASSWORD="${POSTGRES_PASSWORD:=password}"
DB_NAME="${POSTGRES_DB:=newsletter}"
DB_PORT="${POSTGRES_PORT:=5069}"
DB_HOST="${POSTGRES_HOST:=localhost}"
CONTAINER_NAME="rust-newsletter-db"

# If SKIP_DOCKER is empty the condition evaluates to true
if [[ -z "${SKIP_DOCKER}" ]]; then
	docker run \
        --name ${CONTAINER_NAME}
		-e POSTGRES_USER=${DB_USER} \
		-e POSTGRES_PASSWORD=${DB_PASSWORD} \
		-e POSTGRES_DB=${DB_NAME} \
		-p "${DB_PORT}":5432 \
		-d postgres \
		postgres -N 1000
fi

# An entry like 0.0.0.0:5069->5069/tcp, 5432/tcp in the "PORTS" column of the `docker ps --all` output indicates two port mappings for the container.
#
# 0.0.0.0:5069->5069/tcp: This means that port 5069 inside the container is being mapped to port 5069 on the host system using the TCP protocol. The IP address 0.0.0.0 in this context represents all available network interfaces on the host system. So, any incoming requests on port 5069 of the host system will be forwarded to the container.
#
# 5432/tcp: This entry indicates that port 5432 inside the container is exposed, but it is not explicitly mapped to a port on the host system. In this case, the container's service on port 5432 is only accessible from within the container itself or from other containers in the same Docker network. To access this service from the host system or external network, you would need to establish some additional network configuration, such as using Docker's network features or container linking.
#
# Overall, with the given entry, you can access the service running on port 5069 of the container by using localhost:5069 or <host-ip>:5069 on your host system. However, to access the service on port 5432, you would need to consider additional networking configurations.

until docker inspect --format {{.State.Running}} ${CONTAINER_NAME}; do
	echo >&2 "Postgres service ${CONTAINER_NAME} is still unavailable -- sleeping "
	sleep 1
done
echo >&2 "Postgres service ${CONTAINER_NAME} is now up and running on port ${DB_PORT}!"

# Export the DATABASE_URL from `sqlx create database --help`
# See https://www.postgresql.org/docs/15/libpq-connect.html for connection format
export PGPASSWORD="${DB_PASSWORD}"
export DATABASE_URL=postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}
echo ${DATABASE_URL}
sqlx database create
sqlx migrate run

# Once in Postgres you'll need to do a `\list` and then a `\c` to connect to the database inside of Postgres.
docker exec -it rust-newsletter-db psql -U postgres

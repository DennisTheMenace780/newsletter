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
        --name ${CONTAINER_NAME} \
		-e POSTGRES_USER=${DB_USER} \
		-e POSTGRES_PASSWORD=${DB_PASSWORD} \
		-e POSTGRES_DB=${DB_NAME} \
		-p "${DB_PORT}":5432 \
		-d postgres \
		postgres -N 1000
fi

# An entry like 0.0.0.0:5069->5432/tcp in the "PORTS" column of the `docker ps --all` output indicates that the container is bound to all available network interfaces on the host machine, and 5069 is the port on the host that maps to the container. In this case any traffic coming through port 5069 will be sent to port 5432 in the docker container via TCP. Port 5432 is the port where Postgres run.

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

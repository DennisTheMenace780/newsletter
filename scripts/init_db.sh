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

# Allow to skip Docker if a dockerized Postgres database is already running
if [[ -z "${SKIP_DOCKER}" ]]; then
	# if a postgres container is running, print instructions to kill it and exit
	# RUNNING_POSTGRES_CONTAINER=$(docker ps --filter 'name=postgres' --format '{{.ID}}')
	# if [[ -n $RUNNING_POSTGRES_CONTAINER ]]; then
	# 	echo >&2 "there is a postgres container already running, kill it with"
	# 	echo >&2 "    docker kill ${RUNNING_POSTGRES_CONTAINER}"
	# 	exit 1
	# fi
	# Launch postgres using Docker
	docker run \
		--name "rust-newsletter-db" \
		-e POSTGRES_USER=${DB_USER} \
		-e POSTGRES_PASSWORD=${DB_PASSWORD} \
		-e POSTGRES_DB=${DB_NAME} \
		-p "${DB_PORT}":5432 \
		-d \
		postgres:14 -N 1000
	# ^ Increased maximum number of connections for testing purposes
fi
echo >&2 "Postgres service ${CONTAINER_NAME} is now up and running on port ${DB_PORT}!"

# Export the DATABASE_URL from `sqlx create database --help`
# See https://www.postgresql.org/docs/15/libpq-connect.html for connection format
export PGPASSWORD="${DB_PASSWORD}"
export DATABASE_URL=postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}
sqlx database create
sqlx migrate run

# Once in Postgres you'll need to do a `\list` and then a `\c` to connect to the database inside of Postgres.
docker exec -it rust-newsletter-db psql -U postgres

SHELL=/bin/bash

# Include and export the contents of .env file if present
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

secrets:
	@envsubst < config.yaml.tpl > config.yaml

run:
	@hugo server -D

build:
	@hugo --minify


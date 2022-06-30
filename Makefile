SHELL=/bin/bash

# Include and export the contents of .env file if present
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

run:
	@hugo server -D

build:
	@hugo --minify

.PHONY: secrets run build

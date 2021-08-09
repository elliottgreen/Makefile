# Tested with GNU Make 3.8.1
MAKEFLAGS += --warn-undefined-variables
SHELL        	:= /usr/bin/env bash -e

.DEFAULT_GOAL := help

# cribbed from https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html and https://news.ycombinator.com/item?id=11195539
help:  ## Prints out documentation for available commands
	@awk -F ':|##' \
		'/^[^\t].+?:.*?##/ {\
			printf "\033[36m%-30s\033[0m %s\n", $$1, $$NF \
		}' $(MAKEFILE_LIST)

.PHONY: init_env python-install

all: init_env python-install
	export PYTHONPATH=./app

init_env:
	python -m venv env
	if [ ! -e "env/bin/activate_this.py" ] ; \
	then PYTHONPATH=env ; \
	virtualenv --clear env ; \
	fi

.PHONY: python-install
python-install:  requirements.txt ## Sets up your python environment for the first time (only need to run once)
	PYTHONPATH=env ; \
	. env/bin/activate && env/bin/pip install -U pip ; \
	pip install --require-hashes -r requirements.txt ;\

# This will fail is the requirements.txt file already exists. 
requirements.txt: requirements.in
	PYTHONPATH=env ; \
	. env/bin/activate && env/bin/pip install -U pip-tools ; \
	pip-compile --generate-hashes requirements.in --output-file $@

.PHONY: deep-clean
deep-clean: clean  ## Delete python packages and virtualenv. You must run 'make python-install' after running this.
	rm -rf env
	rm -rf htmlcov
	rm coverage.*
	rm *.txt
	@echo virtualenvironment was deleted. Type 'deactivate' to deactivate the shims.

.PHONY: clean
clean:  ## Delete any directories, files or logs that are auto-generated, except node_modules and python packages
	rm -rf results
	rm -rf .pytest_cache
	rm -f .coverage

.PHONY: flake8
flake8: pip-install 	## Run Flake8 python static style checking and linting
	@echo "flake8 comments:"
	flake8 --statistics .

.PHONY: test
test: unit-test flake8 ## Run unit tests, static analysis
	@echo "All tests passed."  # This should only be printed if all of the other targets succeed

.PHONY: pip-upgrade
pip-upgrade:  ## Upgrade all python dependencies
	pip-compile --upgrade --generate-hashes requirements.in --output-file requirements.txt
	pip-compile --upgrade --generate-hashes dev-requirements.in --output-file dev-requirements.txt

SITE_PACKAGES := $(shell pip show pip | grep '^Location' | cut -f2 -d ':')
$(SITE_PACKAGES): requirements.txt dev-requirements.txt
	pip-sync requirements.txt dev-requirements.txt

.PHONY: pip-install
pip-install: $(SITE_PACKAGES)

## Test targets
.PHONY: unit-test
unit-test: pip-install  ## Run python unit tests
	python -m pytest -v --cov --cov-report term --cov-report xml --cov-report html

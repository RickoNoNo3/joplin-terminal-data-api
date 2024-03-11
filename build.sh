#!/bin/bash
docker builder prune --all
docker build -t joplin_terminal_data_api .

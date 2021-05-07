#!/bin/bash

curl -sS http://127.0.0.1:4040/api/tunnels | jq -r "."
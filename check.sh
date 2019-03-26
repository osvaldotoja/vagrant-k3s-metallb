#!/bin/bash

set -euo pipefail

date

echo "Starting checks .."

echo "running vagrant ssh client -c curl -s 192.168.90.192"
until vagrant ssh client -c "curl -s 192.168.90.192" 2>/dev/null
do
	sleep 3
	printf .
done

echo "done"

date

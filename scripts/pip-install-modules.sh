#!/bin/bash

set -xe

MODULES_DIR=${1:-/code/modules}
MODULES_DIR=$(realpath "$MODULES_DIR")

for module_path in "$MODULES_DIR"/{invenio-*,weko-*}; do
  if [ -d "$module_path" ]; then
    module_name=$(basename "$module_path")

    echo "Checking module: $module_name"

    if pip show "$module_name" > /dev/null 2>&1; then
      echo "  → already installed. Skipping..."
    else
      echo "  → not installed. Installing in editable mode..."
      pip install --no-cache-dir -c /code/constraints.txt -e "file://localhost$module_path"
    fi
  fi
done

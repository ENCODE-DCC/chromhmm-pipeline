#!/bin/bash

set -euo pipefail

if [ -z "$(command -v caper)" ]; then
    echo "caper not installed, install with 'pip install caper'"
    exit 1
fi

if [ $# -lt 2 ]; then
    echo "Usage: ./caper_run.sh [WDL] [INPUT_JSON]"
    exit 1
fi

if [ -z "${CHROMHMM_DOCKER_IMAGE_TAG}" ]; then
    echo "Must specify CHROMHMM_DOCKER_IMAGE_TAG via environment variable."
    exit 1
fi

WDL=$1
INPUT=$2

echo "Running caper with WDL ${WDL}, input ${INPUT}, and image ${CHROMHMM_DOCKER_IMAGE_TAG}"

caper run "${WDL}" \
    -i "${INPUT}" \
    --docker "${CHROMHMM_DOCKER_IMAGE_TAG}" \
    -o ./tests/pytest_workflow_options.json \
    --cromwell https://github.com/broadinstitute/cromwell/releases/download/55/cromwell-55.jar \
    --womtool https://github.com/broadinstitute/cromwell/releases/download/55/womtool-55.jar

if [[ -f "cromwell.out" ]]; then
    cat cromwell.out
fi

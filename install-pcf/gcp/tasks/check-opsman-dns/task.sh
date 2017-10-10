#!/bin/bash
set -e

source "pcf-pipelines/functions/check_opsman_available.sh"

echo Opsman variable is:  "${OPSMAN_DOMAIN_OR_IP_ADDRESS}"

opsman_available=$(check_opsman_available "${OPSMAN_DOMAIN_OR_IP_ADDRESS}")
if [[ $opsman_available != "available" ]]; then
  echo Could not reach opsman.${pcf_ert_domain}. Is DNS set up correctly?
  exit 1
fi

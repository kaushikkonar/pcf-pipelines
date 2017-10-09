#!/bin/bash
set -e

source "pcf-pipelines/functions/check_opsman_available.sh"

echo Opsman variable is:  "${opsman_domain_or_ip_address}"

opsman_available=$(check_opsman_available "${opsman_domain_or_ip_address}")
if [[ $opsman_available != "available" ]]; then
  echo Could not reach opsman.${pcf_ert_domain}. Is DNS set up correctly?
  exit 1
fi

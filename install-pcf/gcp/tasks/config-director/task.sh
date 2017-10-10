#!/bin/bash

set -eu

iaas_configuration=$(
  jq -n \
    --arg gcp_project "$GCP_PROJECT_ID" \
    --arg default_deployment_tag "$GCP_RESOURCE_PREFIX" \
    --arg auth_json "$GCP_SERVICE_ACCOUNT_KEY" \
    '
    {
      "project": $gcp_project,
      "default_deployment_tag": $default_deployment_tag,
      "auth_json": $auth_json
    }
    '
)

availability_zones="${GCP_ZONE_1},${GCP_ZONE_2},${GCP_ZONE_3}"

az_configuration=$(
  jq -n \
    --arg availability_zones "$availability_zones" \
    '
    {
      "availability_zones": ($availability_zones | split(",") | map({name: .}))
    }'
)

network_configuration=$(
  jq -n \
    --argjson icmp_checks_enabled false \
    --arg infra_network_name "infra" \
    --arg infra_vcenter_network "${GCP_RESOURCE_PREFIX}-virt-net/infra/${GCP_REGION}" \
    --arg infra_network_cidr "${GCP_RESOURCE_CIDR_OPS}" \
    --arg infra_reserved_ip_ranges "${GCP_RESERVED_OPS_IPS}" \
    --arg infra_dns "${GCP_DNS_IP},8.8.8.8" \
    --arg infra_gateway "${GCP_OPS_GW}" \
    --arg infra_availability_zones "$availability_zones" \
    --arg deployment_network_name "ert" \
    --arg deployment_vcenter_network "${GCP_RESOURCE_PREFIX}-virt-net/ert/${GCP_REGION}" \
    --arg deployment_network_cidr "${GCP_RESOURCE_CIDR_ERT}" \
    --arg deployment_reserved_ip_ranges "${GCP_RESERVED_ERT_IPS}" \
    --arg deployment_dns "${GCP_DNS_IP},8.8.8.8"  \
    --arg deployment_gateway "${GCP_ERT_GW}" \
    --arg deployment_availability_zones "$availability_zones" \
    --arg services_network_name "svcs" \
    --arg services_vcenter_network "${GCP_RESOURCE_PREFIX}-virt-net/svcs/${GCP_REGION}" \
    --arg services_network_cidr "${GCP_RESOURCE_CIDR_SVC}" \
    --arg services_reserved_ip_ranges "${GCP_RESERVED_SVC_IPS}" \
    --arg services_dns "${GCP_DNS_IP},8.8.8.8" \
    --arg services_gateway "${GCP_SVC_GW}" \
    --arg services_availability_zones "$availability_zones" \
    --argjson services_network_is_service_network false \
    --arg dynamic_services_network_name "dyn-svcs" \
    --arg dynamic_services_vcenter_network "${GCP_RESOURCE_PREFIX}-virt-net/dyn-svcs/${GCP_REGION}" \
    --arg dynamic_services_network_cidr "${GCP_RESOURCE_CIDR_DYNSVC}" \
    --arg dynamic_services_reserved_ip_ranges "${GCP_RESERVED_DYNSVC_IPS}" \
    --arg dynamic_services_dns "${GCP_DNS_IP},8.8.8.8" \
    --arg dynamic_services_gateway "${GCP_DYNSVC_GW}" \
    --arg dynamic_services_availability_zones "$availability_zones" \
    --argjson dynamic_services_network_is_service_network true \
    '
    {
      "icmp_checks_enabled": $icmp_checks_enabled,
      "networks": [
        {
          "name": $infra_network_name,
          "service_network": false,
          "subnets": [
            {
              "iaas_identifier": $infra_vcenter_network,
              "cidr": $infra_network_cidr,
              "reserved_ip_ranges": $infra_reserved_ip_ranges,
              "dns": $infra_dns,
              "gateway": $infra_gateway,
              "availability_zones": ($infra_availability_zones | split(","))
            }
          ]
        },
        {
          "name": $deployment_network_name,
          "service_network": false,
          "subnets": [
            {
              "iaas_identifier": $deployment_vcenter_network,
              "cidr": $deployment_network_cidr,
              "reserved_ip_ranges": $deployment_reserved_ip_ranges,
              "dns": $deployment_dns,
              "gateway": $deployment_gateway,
              "availability_zones": ($deployment_availability_zones | split(","))
            }
          ]
        },
        {
          "name": $services_network_name,
          "service_network": $services_network_is_service_network,
          "subnets": [
            {
              "iaas_identifier": $services_vcenter_network,
              "cidr": $services_network_cidr,
              "reserved_ip_ranges": $services_reserved_ip_ranges,
              "dns": $services_dns,
              "gateway": $services_gateway,
              "availability_zones": ($services_availability_zones | split(","))
            }
          ]
        },
        {
          "name": $dynamic_services_network_name,
          "service_network": $dynamic_services_network_is_service_network,
          "subnets": [
            {
              "iaas_identifier": $dynamic_services_vcenter_network,
              "cidr": $dynamic_services_network_cidr,
              "reserved_ip_ranges": $dynamic_services_reserved_ip_ranges,
              "dns": $dynamic_services_dns,
              "gateway": $dynamic_services_gateway,
              "availability_zones": ($dynamic_services_availability_zones | split(","))
            }
          ]
        }
      ]
    }'
)

director_config=$(cat <<-EOF
{
  "ntp_servers_string": "metadata.google.internal",
  "resurrector_enabled": true,
  "retry_bosh_deploys": true,
  "database_type": "external",
  "external_database_options": {
    "host": "$DB_HOST",
    "port": 3306,
    "user": "$DB_USERNAME",
    "password": "$RDS_PASSWORD",
    "database": "$DB_DATABASE"
  },
  "blobstore_type": "local"
}
EOF
)

resource_configuration=$(cat <<-EOF
{
  "director": {
    "internet_connected": true
  },
  "compilation": {
    "internet_connected": true,
    "instance_type": {"id":"xlarge"}
  }
}
EOF
)

security_configuration=$(
  jq -n \
    --arg trusted_certificates "$OPS_MGR_TRUSTED_CERTS" \
    '
    {
      "trusted_certificates": $trusted_certificates,
      "vm_password_type": "generate"
    }'
)

network_assignment=$(
  jq -n \
    --arg availability_zones "$availability_zones" \
    --arg network "infra" \
    '
    {
      "singleton_availability_zone": ($availability_zones | split(",") | .[0]),
      "network": $network
    }'
)

echo "Configuring IaaS and Director..."
om-linux \
  --target https://$OPSMAN_DOMAIN_OR_IP_ADDRESS \
  --skip-ssl-validation \
  --username $OPS_MGR_USR \
  --password $OPS_MGR_PWD \
  configure-bosh \
  --iaas-configuration "$iaas_configuration" \
  --director-configuration "$director_config" \
  --az-configuration "$az_configuration" \
  --networks-configuration "$network_configuration" \
  --network-assignment "$network_assignment" \
  --security-configuration "$security_configuration" \
  --resource-configuration "$resource_configuration"

resource "null_resource" "wait_for_ingressgateway" {
  depends_on = [helm_release.istio_ingressgateway]
  provisioner "local-exec" {
    command = "echo 'Waiting for istio-ingressgateway to become available...'"
  }
}

data "kubernetes_service" "istio_gateway" {
  metadata {
    name      = "istio-ingressgateway"
    namespace = "istio-gateway"
  }
  depends_on = [
    null_resource.wait_for_ingressgateway,
    helm_release.istio_ingressgateway
  ]
}

locals {
  istio_gateway_domain = try(
    data.kubernetes_service.istio_gateway.status[0].load_balancer[0].ingress[0].hostname,
    null
  )
}


# resource "helm_release" "osdu-ir-install" {
#   name      = "osdu-ir-install"
#   chart     = "${path.module}/charts/osdu-gc-baremetal-0.27.2.tgz"
#   version   = "0.27.2"
#   namespace = "default"

#    # Add these parameters to handle existing releases
#   replace          = true
#   force_update     = true
#   recreate_pods    = false
#   reset_values     = false
#   reuse_values     = true

#   lifecycle {
#     ignore_changes = [description]
#   }

#   values = [
#     yamlencode({

#       # ✅ REMOVED: Global tolerations that were causing scheduling issues
#       # Instead, we'll set specific tolerations per component

#       airflow = {
#         enabled          = true
#         fullnameOverride = "airflow"
#         postgresql = {
#           enabled = false
#         }
#         externalDatabase = {
#           host     = "postgresql-db"
#           user     = "airflow_owner"
#           password = "admin123"
#           database = "airflow"
#         }
#         rbac = {
#           create = true
#         }
#         serviceaccount = {
#           create = true
#         }
#         ingress = {
#           enabled = false
#         }
#         auth = {
#           username = "admin"
#           password = "admin123"
#         }
#         dags = {
#           existingConfigmap = "dags-config"
#         }
#         worker = {
#           extraEnvVarsCM     = "airflow-config"
#           extraEnvVarsSecret = "airflow-secret"
#           podAnnotations = {
#             "sidecar.istio.io/inject" = "false"
#           }
#           automountServiceAccountToken = true
#           # ✅ FRONTEND NODES: Airflow worker on frontend (no nodeSelector = flexible scheduling)
#         }
#         web = {
#           extraEnvVarsCM     = "airflow-config"
#           extraEnvVarsSecret = "airflow-secret"
#           resources = {
#             requests = {
#               cpu    = "600m"
#               memory = "1152Mi"
#             }
#             limits = {
#               cpu    = "2750m"
#               memory = "2560Mi"
#             }
#           }
#           # ✅ FRONTEND NODES: Airflow web on frontend (no nodeSelector = flexible scheduling)
#         }
#         scheduler = {
#           extraEnvVarsCM     = "airflow-config"
#           extraEnvVarsSecret = "airflow-secret"
#           resources = {
#             requests = {
#               cpu    = "600m"
#               memory = "640Mi"
#             }
#             limits = {
#               cpu    = "2750m"
#               memory = "2Gi"
#             }
#           }
#           # ✅ FRONTEND NODES: Airflow scheduler on frontend (no nodeSelector = flexible scheduling)
#         }
#       }

#       istio = {
#         gateway = "istio-ingressgateway"
#       }

#       global = {
#         # ✅ NO global nodeSelector - let each component choose its placement
#         dataPartitionId = "osdu"
#         domain          = local.istio_gateway_domain
#         onPremEnabled = true
#         useHttps      = false
#         limitsEnabled = true
#         logLevel      = "ERROR"
#       }

#       domain = {
#         tls = {
#           osduCredentialName     = "osdu-ingress-tls"
#           minioCredentialName    = "minio-ingress-tls"
#           s3CredentialName       = "s3-ingress-tls"
#           keycloakCredentialName = "keycloak-ingress-tls"
#           airflowCredentialName  = "airflow-ingress-tls"
#         }
#       }

#       conf = {
#         createSecrets = true
#         nameSuffix    = ""
#       }

#       # ===== BACKEND NODE COMPONENTS =====
#       minio = {
#         mode             = "standalone"
#         enabled          = true
#         fullnameOverride = "minio"
#         statefulset = {
#           replicaCount  = 1
#           drivesPerNode = 4
#         }
#         auth = {
#           rootUser     = "minio"
#           rootPassword = "admin123"
#         }
#         persistence = {
#           enabled      = true
#           size         = "20Gi"
#           storageClass = "gp2"
#           mountPath    = "/bitnami/minio/data"
#         }
#         extraEnvVarsCM       = "minio-config"
#         useInternalServerUrl = false
#         # ✅ BACKEND NODE: MinIO placement
#         nodeSelector = {
#           "node-role" = "osdu-backend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-backend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       rabbitmq = {
#         enabled          = true
#         fullnameOverride = "rabbitmq"
#         auth = {
#           username = "rabbitmq"
#           password = "admin123"
#         }
#         replicaCount = 1
#         loadDefinition = {
#           enabled        = true
#           existingSecret = "load-definition"
#         }
#         logs          = "-"
#         configuration = <<-EOT
#       ## Username and password
#       default_user = rabbitmq
#       ## Clustering
#       cluster_name = rabbitmq
#       cluster_formation.peer_discovery_backend  = rabbit_peer_discovery_k8s
#       cluster_formation.k8s.host = kubernetes.default
#       cluster_formation.k8s.address_type = hostname
#       cluster_formation.k8s.service_name = rabbitmq-headless
#       cluster_formation.k8s.hostname_suffix = .rabbitmq-headless.default.svc.cluster.local      
#       cluster_formation.node_cleanup.interval = 10
#       cluster_formation.node_cleanup.only_log_warning = true
#       cluster_partition_handling = autoheal
#       load_definitions = /app/load_definition.json
#       # queue master locator
#       queue_master_locator = min-masters
#       # enable guest user
#       loopback_users.guest = false
#       # log level setup
#       log.connection.level = error
#       log.default.level = error
#     EOT
#         # ✅ BACKEND NODE: RabbitMQ placement
#         nodeSelector = {
#           "node-role" = "osdu-backend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-backend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       postgresql = {
#         enabled          = true
#         fullnameOverride = "postgresql-db"

#         global = {
#           postgresql = {
#             auth = {
#               postgresPassword = "admin123"
#               database         = "postgres"
#             }
#           }
#         }

#         primary = {
#           persistence = {
#             enabled      = true
#             size         = "20Gi"
#             storageClass = "gp2"
#           }
#           resourcesPreset = "medium"
#           # ✅ BACKEND NODE: PostgreSQL placement
#           nodeSelector = {
#             "node-role" = "osdu-backend"
#           }
#           tolerations = [
#             {
#               key      = "node-role"
#               operator = "Equal"
#               value    = "osdu-backend"
#               effect   = "NoSchedule"
#             }
#           ]
#         }
#       }

#       elasticsearch = {
#         enabled          = true
#         fullnameOverride = "elasticsearch"

#         security = {
#           enabled         = true
#           elasticPassword = "admin123"
#           tls = {
#             autoGenerated = true
#           }
#         }

#         master = {
#           fullnameOverride = "elasticsearch"
#           masterOnly       = false
#           heapSize         = "1024m"
#           replicas         = "1"
#           persistence = {
#             size         = "10Gi"
#             storageClass = "gp2"
#           }
#           # ✅ BACKEND NODE: Elasticsearch master placement
#           nodeSelector = {
#             "node-role" = "osdu-backend"
#           }
#           tolerations = [
#             {
#               key      = "node-role"
#               operator = "Equal"
#               value    = "osdu-backend"
#               effect   = "NoSchedule"
#             }
#           ]
#         }

#         coordinating = {
#           replicas = "0"
#         }

#         data = {
#           replicas = "1"
#           persistence = {
#             size         = "30Gi"
#             storageClass = "gp2"
#           }
#           # ✅ BACKEND NODE: Elasticsearch data placement
#           nodeSelector = {
#             "node-role" = "osdu-backend"
#           }
#           tolerations = [
#             {
#               key      = "node-role"
#               operator = "Equal"
#               value    = "osdu-backend"
#               effect   = "NoSchedule"
#             }
#           ]
#         }

#         ingest = {
#           replicas = "0"
#         }
#       }

#       # ===== ISTIO-KEYCLOAK NODE COMPONENTS =====
#       keycloak = {
#         enabled          = true
#         fullnameOverride = "keycloak"

#         auth = {
#           adminPassword = "admin123"
#         }

#         service = {
#           type = "ClusterIP"
#         }

#         postgresql = {
#           enabled = false
#         }

#         externalDatabase = {
#           existingSecret            = "keycloak-database-secret"
#           existingSecretPasswordKey = "KEYCLOAK_DATABASE_PASSWORD"
#           existingSecretHostKey     = "KEYCLOAK_DATABASE_HOST"
#           existingSecretPortKey     = "KEYCLOAK_DATABASE_PORT"
#           existingSecretUserKey     = "KEYCLOAK_DATABASE_USER"
#           existingSecretDatabaseKey = "KEYCLOAK_DATABASE_NAME"
#         }

#         proxy = "none"

#         # ✅ ISTIO NODE: Keycloak placement
#         nodeSelector = {
#           "node-role" = "osdu-istio-keycloak"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-istio-keycloak"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       # ===== BOOTSTRAP COMPONENTS =====
#       bootstrap = {
#         # ✅ BACKEND NODE: Database bootstrap components
#         nodeSelector = {
#           "node-role" = "osdu-backend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-backend"
#             effect   = "NoSchedule"
#           }
#         ]

#         airflow = {
#           dagImages = {
#             csv_parser  = "community.opengroup.org:5555/osdu/platform/data-flow/ingestion/csv-parser/csv-parser/gc-csv-parser:v0.27.0"
#             segy_to_zgy = "community.opengroup.org:5555/osdu/platform/data-flow/ingestion/segy-to-zgy-conversion/gc-segy-to-zgy:v0.27.2"
#             open_vds    = "community.opengroup.org:5555/osdu/platform/domain-data-mgmt-services/seismic/open-vds/openvds-ingestion:3.4.5"
#             energistics = "community.opengroup.org:5555/osdu/platform/data-flow/ingestion/energistics/witsml-parser/gc-baremetal-energistics:v0.27.0"
#           }
#           username = "admin"
#           password = "admin123"
#         }

#         postgres = {
#           external           = false
#           cloudSqlConnection = ""

#           keycloak = {
#             host     = "postgresql-db"
#             port     = "5432"
#             name     = "keycloak"
#             user     = "keycloak_owner"
#             password = "admin123"
#           }

#           dataset = {
#             host     = "postgresql-db"
#             port     = "5432"
#             name     = "dataset"
#             user     = "dataset"
#             password = "admin123"
#           }

#           entitlements = {
#             host     = "postgresql-db"
#             port     = "5432"
#             name     = "entitlements"
#             user     = "entitlements"
#             password = "admin123"
#             schema   = "entitlements_osdu_1"
#           }

#           file = {
#             host     = "postgresql-db"
#             port     = "5432"
#             name     = "file"
#             user     = "file_owner"
#             password = "admin123"
#           }

#           legal = {
#             host     = "postgresql-db"
#             port     = "5432"
#             name     = "legal"
#             user     = "legal_owner"
#             password = "admin123"
#           }

#           partition = {
#             host     = "postgresql-db"
#             port     = "5432"
#             name     = "partition"
#             user     = "partition"
#             password = "admin123"
#           }

#           register = {
#             host     = "postgresql-db"
#             port     = "5432"
#             name     = "register"
#             user     = "register_owner"
#             password = "admin123"
#           }

#           schema = {
#             host     = "postgresql-db"
#             port     = "5432"
#             name     = "schema"
#             user     = "schema"
#             password = "admin123"
#           }

#           seismic = {
#             host     = "postgresql-db"
#             port     = "5432"
#             name     = "seismic"
#             user     = "seismic"
#             password = "admin123"
#           }

#           storage = {
#             host     = "postgresql-db"
#             port     = "5432"
#             name     = "storage"
#             user     = "storage_owner"
#             password = "admin123"
#           }

#           well_delivery = {
#             host     = "postgresql-db"
#             port     = "5432"
#             name     = "well-delivery"
#             user     = "well_delivery_owner"
#             password = "admin123"
#           }

#           wellbore = {
#             host     = "postgresql-db"
#             port     = "5432"
#             name     = "wellbore"
#             user     = "wellbore"
#             password = "admin123"
#           }

#           workflow = {
#             host             = "postgresql-db"
#             port             = "5432"
#             name             = "workflow"
#             user             = "workflow"
#             password         = "admin123"
#             system_namespace = "osdu"
#           }

#           secret = {
#             postgresqlUser = "postgres"
#             postgresqlPort = "5432"
#           }
#         }

#         elastic = {
#           secret = {
#             elasticHost        = "elasticsearch"
#             elasticPort        = "9200"
#             elasticAdmin       = "elastic"
#             elasticSearchUser  = "search-service"
#             elasticIndexerUser = "indexer-service"
#           }
#           imagePullSecrets = []
#         }

#         minio = {
#           external    = false
#           console_url = ""
#           api_url     = ""

#           policy = {
#             user     = "admin"
#             password = "admin123"
#           }

#           airflow = {
#             user     = "admin"
#             password = "admin123"
#           }

#           file = {
#             user     = "admin"
#             password = "admin123"
#           }

#           legal = {
#             user     = "admin"
#             password = "admin123"
#           }

#           storage = {
#             user     = "admin"
#             password = "admin123"
#           }

#           seismicStore = {
#             user     = "admin"
#             password = "admin123"
#             bucket   = ""
#           }

#           schema = {
#             user     = "admin"
#             password = "admin123"
#           }

#           wellbore = {
#             user     = "admin"
#             password = "admin123"
#           }

#           dag = {
#             user     = "admin"
#             password = "admin123"
#           }
#         }

#         keycloak = {
#           secret = {
#             keycloakService   = "http://keycloak"
#             keycloakRealmName = "osdu"
#           }
#         }
#       }

#       # ✅ BACKEND NODE: Infrastructure bootstrap
#       gc_baremetal_infra_bootstrap = {
#         enabled = true
#         nodeSelector = {
#           "node-role" = "osdu-backend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-backend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       # ✅ BACKEND NODE: RabbitMQ bootstrap
#       rabbitmq_bootstrap = {
#         enabled = true
#         nodeSelector = {
#           "node-role" = "osdu-backend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-backend"
#             effect   = "NoSchedule"
#           }
#         ]
#         data = {
#           rabbitmqHost                = "rabbitmq"
#           rabbitmqVhost               = "/"
#           bootstrapServiceAccountName = "bootstrap-sa"
#         }
#       }

#       # ✅ ADDED: Specific bootstrap component overrides for correct scheduling
#       # ✅ BACKEND NODE: PostgreSQL bootstrap
#       postgres_bootstrap = {
#         enabled = true
#         nodeSelector = {
#           "node-role" = "osdu-backend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-backend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       # ✅ BACKEND NODE: MinIO bootstrap
#       minio_bootstrap = {
#         enabled = true
#         nodeSelector = {
#           "node-role" = "osdu-backend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-backend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       # ✅ BACKEND NODE: Elasticsearch bootstrap
#       elastic_bootstrap = {
#         enabled = true
#         nodeSelector = {
#           "node-role" = "osdu-backend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-backend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       # ✅ ISTIO NODE: Keycloak bootstrap
#       keycloak_bootstrap = {
#         enabled = true
#         nodeSelector = {
#           "node-role" = "osdu-istio-keycloak"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-istio-keycloak"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       # ✅ FRONTEND NODE: Airflow bootstrap (no nodeSelector = flexible scheduling)
#       airflow_bootstrap = {
#         enabled = true
#         # ✅ NO nodeSelector = will schedule on available frontend nodes
#       }

#       # This entire block is not required because these are Google Cloud Platform related params
#       gc_infra_bootstrap = {
#         enabled = false
#         data = {
#           projectId          = ""
#           serviceAccountName = "infra-bootstrap"
#         }
#         airflow = {
#           bucket          = ""
#           environmentName = ""
#           location        = ""
#           dagImages = {
#             csv_parser  = "community.opengroup.org:5555/osdu/platform/data-flow/ingestion/csv-parser/csv-parser/gc-csv-parser:v0.27.0"
#             segy_to_zgy = "community.opengroup.org:5555/osdu/platform/data-flow/ingestion/segy-to-zgy-conversion/gc-segy-to-zgy:v0.27.2"
#             open_vds    = "community.opengroup.org:5555/osdu/platform/domain-data-mgmt-services/seismic/open-vds/openvds-ingestion:3.4.5"
#             energistics = "community.opengroup.org:5555/osdu/platform/data-flow/ingestion/energistics/witsml-parser/gc-energistics:v0.27.0"
#           }
#         }
#       }

#       # ===== OSDU MICROSERVICES (FRONTEND NODES) =====
#       # ✅ These will automatically schedule on frontend nodes since they have no nodeSelector/tolerations
      
#       gc_entitlements_deploy = {
#         enabled = true
#         data = {
#           bootstrapServiceAccountName = "bootstrap-sa"
#           adminUserEmail              = "osdu-admin@service.local"
#           airflowComposerEmail        = "airflow@service.local"
#         }
#         # ✅ NO nodeSelector = will schedule on available frontend nodes
#       }

#       gc_config_deploy = {
#         enabled = true
#         # ✅ NO nodeSelector = will schedule on available frontend nodes
#       }

#       gc-crs-catalog-deploy = {
#         enabled = true
#         data = {
#           serviceAccountName = "crs-catalog"
#         }
#         # ✅ NO nodeSelector = will schedule on available frontend nodes
#       }

#       gc_dataset_deploy = {
#         enabled = true
#         data = {
#           serviceAccountName = "dataset"
#         }
#         conf = {
#           postgresSecretName = "dataset-postgres-secret"
#         }
#         # ✅ NO nodeSelector = will schedule on available frontend nodes
#       }

#       gc-crs-conversion-deploy = {
#         enabled = true
#         # ✅ NO nodeSelector = will schedule on available frontend nodes
#       }

#       gc_partition_deploy = {
#         enabled = true
#         data = {
#           policyServiceEnabled  = "true"
#           edsEnabled            = "false"
#           autocompleteEnabled   = "false"
#           minioExternalEndpoint = ""
#         }
#         # ✅ NO nodeSelector = will schedule on available frontend nodes
#       }

#       gc_policy_deploy = {
#         enabled = true
#         data = {
#           bucketName                  = "refi-opa-policies"
#           bootstrapServiceAccountName = "bootstrap-sa"
#         }
#         # ✅ NO nodeSelector = will schedule on available frontend nodes
#       }

#       gc_storage_deploy = {
#         enabled = true
#         data = {
#           bootstrapServiceAccountName = "bootstrap-sa"
#           opaEnabled                  = true
#         }
#         # ✅ NO nodeSelector = will schedule on available frontend nodes
#       }

#       gc_unit_deploy = {
#         enabled = true
#         # ✅ NO nodeSelector = will schedule on available frontend nodes
#       }

#       gc_register_deploy = {
#         enabled = true
#         data = {
#           serviceAccountName = "register"
#         }
#         conf = {
#           rabbitmqSecretName         = "rabbitmq-secret"
#           registerPostgresSecretName = "register-postgres-secret"
#           registerKeycloakSecretName = "register-keycloak-secret"
#         }
#         # ✅ NO nodeSelector = will schedule on available frontend nodes
#       }

#       gc_notification_deploy = {
#         enabled = true
#         # ✅ NO nodeSelector = will schedule on available frontend nodes
#       }

#       gc_well_delivery_deploy = {
#         enabled = true
#         # ✅ NO nodeSelector = will schedule on available frontend nodes
#       }

#       gc_workflow_deploy = {
#         enabled = true
#         data = {
#           sharedTenantName            = "osdu"
#           bootstrapServiceAccountName = "bootstrap-sa"
#         }
#         # ✅ NO nodeSelector = will schedule on available frontend nodes
#       }

#       gc_file_deploy = {
#         enabled = true
#         data = {
#           serviceAccountName = "file"
#         }
#         # ✅ NO nodeSelector = will schedule on available frontend nodes
#       }

#       gc_schema_deploy = {
#         enabled = true
#         data = {
#           bootstrapServiceAccountName = "bootstrap-sa"
#         }
#         conf = {
#           bootstrapSecretName = "datafier-secret"
#           minioSecretName     = "schema-minio-secret"
#           postgresSecretName  = "schema-postgres-secret"
#           rabbitmqSecretName  = "rabbitmq-secret"
#         }
#         # ✅ NO nodeSelector = will schedule on available frontend nodes
#       }

#       gc_search_deploy = {
#         enabled = true
#         data = {
#           servicePolicyEnabled = true
#         }
#         # ✅ NO nodeSelector = will schedule on available frontend nodes
#       }

#       gc_seismic_store_sdms_deploy = {
#         enabled = true
#         data = {
#           redisDdmsHost = "redis-ddms"
#         }
#         # ✅ NO nodeSelector = will schedule on available frontend nodes
#       }

#       gc_indexer_deploy = {
#         enabled = true
#         conf = {
#           elasticSecretName  = "indexer-elastic-secret"
#           keycloakSecretName = "indexer-keycloak-secret"
#           rabbitmqSecretName = "rabbitmq-secret"
#         }
#         # ✅ NO nodeSelector = will schedule on available frontend nodes
#       }

#       gc_legal_deploy = {
#         enabled = false
#       }

#       core_legal_deploy = {
#         enabled = true
#         data = {
#           image                     = "community.opengroup.org:5555/osdu/platform/security-and-compliance/legal/core-plus-legal-master:latest"
#           legalStatusUpdateImage    = "community.opengroup.org:5555/osdu/platform/security-and-compliance/legal/core-plus-legal-master:latest"
#           imagePullPolicy           = "IfNotPresent"
#           cronJobServiceAccountName = "bootstrap-sa"
#         }
#         # ✅ NO nodeSelector = will schedule on available frontend nodes
#       }

#       gc_wellbore_deploy = {
#         enabled = true
#         # ✅ NO nodeSelector = will schedule on available frontend nodes
#       }

#       gc_wellbore_worker_deploy = {
#         enabled = true
#         # ✅ NO nodeSelector = will schedule on available frontend nodes
#       }

#       gc_secret_deploy = {
#         enabled = true
#         # ✅ NO nodeSelector = will schedule on available frontend nodes
#       }

#       gc_eds_dms_deploy = {
#         enabled = true
#         # ✅ NO nodeSelector = will schedule on available frontend nodes
#       }

#       gc_oetp_client_deploy = {
#         enabled = false
#       }

#       gc_oetp_server_deploy = {
#         enabled = false
#       }

#       dfaas_tests = {
#         enabled = false
#       }
#     })
#   ]
#   timeout           = 1200
#   wait              = true
#   dependency_update = true
#   depends_on = [
#     aws_eks_addon.osdu-ir-csi-addon,
#     null_resource.update_kubeconfig,
#     null_resource.label_default_namespace,
#     helm_release.istio_ingressgateway
#   ]
# }


###########################################################################################################

resource "helm_release" "osdu-ir-install" {
  name      = "osdu-ir-install"
  chart     = "${path.module}/charts/osdu-gc-baremetal-0.27.2.tgz"
  version   = "0.27.2"
  namespace = "default"

   # Add these parameters to handle existing releases
  replace          = true
  force_update     = true
  recreate_pods    = false
  reset_values     = false
  reuse_values     = true

# # Keep only these safe parameters:
#   wait           = true
#   wait_for_jobs  = true
#   timeout        = 600


  lifecycle {
    ignore_changes = [description]
  }

  values = [
    yamlencode({

      # ✅ ADDED: Global tolerations for all node groups
      tolerations = [
        {
          key      = "node-role"
          operator = "Equal"
          value    = "osdu-backend"
          effect   = "NoSchedule"
        },
        {
          key      = "node-role"
          operator = "Equal"
          value    = "osdu-istio-keycloak"
          effect   = "NoSchedule"
        }
      ]

      airflow = {
        enabled          = true
        fullnameOverride = "airflow"
        postgresql = {
          enabled = false
        }
        externalDatabase = {
          host     = "postgresql-db"
          user     = "airflow_owner"
          password = "admin123"
          database = "airflow"
        }
        rbac = {
          create = true
        }
        serviceaccount = {
          create = true
        }
        ingress = {
          enabled = false
        }
        auth = {
          username = "admin"
          password = "admin123"
        }
        dags = {
          existingConfigmap = "dags-config"
        }
        worker = {
          extraEnvVarsCM     = "airflow-config"
          extraEnvVarsSecret = "airflow-secret"
          podAnnotations = {
            "sidecar.istio.io/inject" = "false"
          }
          automountServiceAccountToken = true
        }
        web = {
          extraEnvVarsCM     = "airflow-config"
          extraEnvVarsSecret = "airflow-secret"
          resources = {
            requests = {
              cpu    = "500m"
              memory = "1024Mi"
            }
            limits = {
              cpu    = "750m"
              memory = "1536Mi"
            }
          }
        }
        scheduler = {
          extraEnvVarsCM     = "airflow-config"
          extraEnvVarsSecret = "airflow-secret"
          resources = {
            requests = {
              cpu    = "500m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "750m"
              memory = "1024Mi"
            }
          }
        }
        # ✅ REMOVED: No nodeSelector/tolerations needed - will schedule on available (frontend) nodes
      }

      istio = {
        gateway = "istio-ingressgateway"
      }

      global = {
        # ✅ REMOVED: No global nodeSelector - let microservices schedule on available nodes
        dataPartitionId = "osdu"
        domain          = local.istio_gateway_domain
        #domain        = "ae490a26db4054424af33224a83dc6d2-1413201501.us-east-1.elb.amazonaws.com"
        onPremEnabled = true
        useHttps      = false # making this true will require us to install the tsl certificates mentione in domain.tls
        limitsEnabled = true
        logLevel      = "ERROR"
      }

      domain = {
        # These certificates must be installed when we change to global.useHttps = true.
        tls = {
          osduCredentialName     = "osdu-ingress-tls"
          minioCredentialName    = "minio-ingress-tls"
          s3CredentialName       = "s3-ingress-tls"
          keycloakCredentialName = "keycloak-ingress-tls"
          airflowCredentialName  = "airflow-ingress-tls"
        }
      }

      conf = {
        createSecrets = true
        nameSuffix    = ""
      }

      minio = {
        mode             = "standalone"
        enabled          = true
        fullnameOverride = "minio"
        statefulset = {
          replicaCount  = 1
          drivesPerNode = 4
        }
        auth = {
          rootUser     = "minio"
          rootPassword = "admin123"
        }
        persistence = {
          enabled      = true
          size         = "20Gi"
          storageClass = "gp2"
          mountPath    = "/bitnami/minio/data" # FIXME: delete it after MinIO chart update
        }
        extraEnvVarsCM       = "minio-config"
        useInternalServerUrl = false
        nodeSelector = {
          "node-role" = "osdu-backend"  # ✅ BACKEND NODE: MinIO on backend
        }
        tolerations = [
          {
            key      = "node-role"  # ✅ FIXED: Changed from "role" to "node-role"
            operator = "Equal"
            value    = "osdu-backend"
            effect   = "NoSchedule"
          }
        ]
      }

      rabbitmq = {
        enabled          = true
        fullnameOverride = "rabbitmq"
        auth = {
          username = "rabbitmq"
          password = "admin123"
        }
        replicaCount = 1
        loadDefinition = {
          enabled        = true
          existingSecret = "load-definition"
        }
        logs          = "-"
        configuration = <<-EOT
      ## Username and password
      ##
      default_user = rabbitmq
      ## Clustering
      cluster_name = rabbitmq
      cluster_formation.peer_discovery_backend  = rabbit_peer_discovery_k8s
      cluster_formation.k8s.host = kubernetes.default
      cluster_formation.k8s.address_type = hostname
      cluster_formation.k8s.service_name = rabbitmq-headless
      cluster_formation.k8s.hostname_suffix = .rabbitmq-headless.default.svc.cluster.local      
      cluster_formation.node_cleanup.interval = 10
      cluster_formation.node_cleanup.only_log_warning = true
      cluster_partition_handling = autoheal
      load_definitions = /app/load_definition.json
      # queue master locator
      queue_master_locator = min-masters
      # enable guest user
      loopback_users.guest = false
      # log level setup
      log.connection.level = error
      log.default.level = error
    EOT
        nodeSelector = {
          "node-role" = "osdu-backend"  # ✅ BACKEND NODE: RabbitMQ on backend
        }
        tolerations = [
          {
            key      = "node-role"  # ✅ FIXED: Changed from "role" to "node-role"
            operator = "Equal"
            value    = "osdu-backend"
            effect   = "NoSchedule"
          }
        ]
      }

      postgresql = {
        enabled          = true
        fullnameOverride = "postgresql-db"

        global = {
          postgresql = {
            auth = {
              postgresPassword = "admin123"
              database         = "postgres"
            }
          }
        }

        primary = {
          persistence = {
            enabled      = true
            size         = "20Gi"
            storageClass = "gp2"
          }
          resourcesPreset = "medium"
        }

        nodeSelector = {
          "node-role" = "osdu-backend"  # ✅ BACKEND NODE: PostgreSQL on backend
        }

        tolerations = [
          {
            key      = "node-role"  # ✅ FIXED: Changed from "role" to "node-role"
            operator = "Equal"
            value    = "osdu-backend"
            effect   = "NoSchedule"
          }
        ]
      }

      elasticsearch = {
        enabled          = true
        fullnameOverride = "elasticsearch"

        security = {
          enabled         = true
          elasticPassword = "admin123"
          tls = {
            autoGenerated = true
          }
        }

        master = {
          fullnameOverride = "elasticsearch"
          masterOnly       = false
          heapSize         = "1024m"
          replicas         = "1"
          persistence = {
            size         = "10Gi"
            storageClass = "gp2"
          }
        }

        coordinating = {
          replicas = "0"
        }

        data = {
          replicas = "1"
          persistence = {
            size         = "30Gi"
            storageClass = "gp2"
          }
        }

        ingest = {
          replicas = "0"
        }

        nodeSelector = {
          "node-role" = "osdu-backend"  # ✅ BACKEND NODE: Elasticsearch on backend
        }

        tolerations = [
          {
            key      = "node-role"  # ✅ FIXED: Changed from "role" to "node-role"
            operator = "Equal"
            value    = "osdu-backend"
            effect   = "NoSchedule"
          }
        ]
      }

      keycloak = {
        enabled          = true
        fullnameOverride = "keycloak"

        auth = {
          adminPassword = "admin123"
        }

        service = {
          type = "ClusterIP"
        }

        postgresql = {
          enabled = false
        }

        externalDatabase = {
          existingSecret            = "keycloak-database-secret"
          existingSecretPasswordKey = "KEYCLOAK_DATABASE_PASSWORD"
          existingSecretHostKey     = "KEYCLOAK_DATABASE_HOST"
          existingSecretPortKey     = "KEYCLOAK_DATABASE_PORT"
          existingSecretUserKey     = "KEYCLOAK_DATABASE_USER"
          existingSecretDatabaseKey = "KEYCLOAK_DATABASE_NAME"
        }

        proxy = "none" # This value will become proxy="edge" when global.useHttps = true

        nodeSelector = {
          "node-role" = "osdu-istio-keycloak"  # ✅ ISTIO NODE: Keycloak on istio-keycloak
        }

        tolerations = [
          {
            key      = "node-role"  # ✅ FIXED: Changed from "role" to "node-role"
            operator = "Equal"
            value    = "osdu-istio-keycloak"
            effect   = "NoSchedule"
          }
        ]
      }

      bootstrap = {
        # ✅ ADDED: Bootstrap components on istio-keycloak nodes
        nodeSelector = {
          "node-role" = "osdu-istio-keycloak"
        }
        tolerations = [
          {
            key      = "node-role"
            operator = "Equal"
            value    = "osdu-istio-keycloak"
            effect   = "NoSchedule"
          }
        ]

        airflow = {
          dagImages = {
            csv_parser  = "community.opengroup.org:5555/osdu/platform/data-flow/ingestion/csv-parser/csv-parser/gc-csv-parser:v0.27.0"
            segy_to_zgy = "community.opengroup.org:5555/osdu/platform/data-flow/ingestion/segy-to-zgy-conversion/gc-segy-to-zgy:v0.27.2"
            open_vds    = "community.opengroup.org:5555/osdu/platform/domain-data-mgmt-services/seismic/open-vds/openvds-ingestion:3.4.5"
            energistics = "community.opengroup.org:5555/osdu/platform/data-flow/ingestion/energistics/witsml-parser/gc-baremetal-energistics:v0.27.0"
          }
          username = "admin"
          password = "admin123"
        }

        postgres = {
          external           = false
          cloudSqlConnection = ""

          keycloak = {
            host     = "postgresql-db"
            port     = "5432"
            name     = "keycloak"
            user     = "keycloak_owner"
            password = "admin123"
          }

          dataset = {
            host     = "postgresql-db"
            port     = "5432"
            name     = "dataset"
            user     = "dataset"
            password = "admin123"
          }

          entitlements = {
            host     = "postgresql-db"
            port     = "5432"
            name     = "entitlements"
            user     = "entitlements"
            password = "admin123"
            schema   = "entitlements_osdu_1"
          }

          file = {
            host     = "postgresql-db"
            port     = "5432"
            name     = "file"
            user     = "file_owner"
            password = "admin123"
          }

          legal = {
            host     = "postgresql-db"
            port     = "5432"
            name     = "legal"
            user     = "legal_owner"
            password = "admin123"
          }

          partition = {
            host     = "postgresql-db"
            port     = "5432"
            name     = "partition"
            user     = "partition"
            password = "admin123"
          }

          register = {
            host     = "postgresql-db"
            port     = "5432"
            name     = "register"
            user     = "register_owner"
            password = "admin123"
          }

          schema = {
            host     = "postgresql-db"
            port     = "5432"
            name     = "schema"
            user     = "schema"
            password = "admin123"
          }

          seismic = {
            host     = "postgresql-db"
            port     = "5432"
            name     = "seismic"
            user     = "seismic"
            password = "admin123"
          }

          storage = {
            host     = "postgresql-db"
            port     = "5432"
            name     = "storage"
            user     = "storage_owner"
            password = "admin123"
          }

          well_delivery = {
            host     = "postgresql-db"
            port     = "5432"
            name     = "well-delivery"
            user     = "well_delivery_owner"
            password = "admin123"
          }

          wellbore = {
            host     = "postgresql-db"
            port     = "5432"
            name     = "wellbore"
            user     = "wellbore"
            password = "admin123"
          }

          workflow = {
            host             = "postgresql-db"
            port             = "5432"
            name             = "workflow"
            user             = "workflow"
            password         = "admin123"
            system_namespace = "osdu"
          }

          secret = {
            postgresqlUser = "postgres"
            postgresqlPort = "5432"
          }
        }

        elastic = {
          secret = {
            elasticHost        = "elasticsearch"
            elasticPort        = "9200"
            elasticAdmin       = "elastic"
            elasticSearchUser  = "search-service"
            elasticIndexerUser = "indexer-service"
          }
          imagePullSecrets = []
        }

        minio = {
          external    = false
          console_url = ""
          api_url     = ""

          policy = {
            user     = "admin"
            password = "admin123"
          }

          airflow = {
            user     = "admin"
            password = "admin123"
          }

          file = {
            user     = "admin"
            password = "admin123"
          }

          legal = {
            user     = "admin"
            password = "admin123"
          }

          storage = {
            user     = "admin"
            password = "admin123"
          }

          seismicStore = {
            user     = "admin"
            password = "admin123"
            bucket   = ""
          }

          schema = {
            user     = "admin"
            password = "admin123"
          }

          wellbore = {
            user     = "admin"
            password = "admin123"
          }

          dag = {
            user     = "admin"
            password = "admin123"
          }
        }

        keycloak = {
          secret = {
            keycloakService   = "http://keycloak"
            keycloakRealmName = "osdu"
          }
        }
      }

      gc_baremetal_infra_bootstrap = {
        enabled = true
        # ✅ ADDED: Bootstrap infrastructure on istio-keycloak nodes
        nodeSelector = {
          "node-role" = "osdu-istio-keycloak"
        }
        tolerations = [
          {
            key      = "node-role"
            operator = "Equal"
            value    = "osdu-istio-keycloak"
            effect   = "NoSchedule"
          }
        ]
      }

      rabbitmq_bootstrap = {
        enabled = true
        # ✅ ADDED: RabbitMQ bootstrap on istio-keycloak nodes
        nodeSelector = {
          "node-role" = "osdu-istio-keycloak"
        }
        tolerations = [
          {
            key      = "node-role"
            operator = "Equal"
            value    = "osdu-istio-keycloak"
            effect   = "NoSchedule"
          }
        ]
        data = {
          rabbitmqHost                = "rabbitmq" # matches fullnameOverride
          rabbitmqVhost               = "/"
          bootstrapServiceAccountName = "bootstrap-sa"
        }
      }

      # This entire block is not required because these are Google Cloud Platform related params. Hence enabled=false
      # Dont make enabled = true.
      gc_infra_bootstrap = {
        enabled = false
        data = {
          projectId          = ""
          serviceAccountName = "infra-bootstrap"
        }
        airflow = {
          bucket          = ""
          environmentName = ""
          location        = ""
          dagImages = {
            csv_parser  = "community.opengroup.org:5555/osdu/platform/data-flow/ingestion/csv-parser/csv-parser/gc-csv-parser:v0.27.0"
            segy_to_zgy = "community.opengroup.org:5555/osdu/platform/data-flow/ingestion/segy-to-zgy-conversion/gc-segy-to-zgy:v0.27.2"
            open_vds    = "community.opengroup.org:5555/osdu/platform/domain-data-mgmt-services/seismic/open-vds/openvds-ingestion:3.4.5"
            energistics = "community.opengroup.org:5555/osdu/platform/data-flow/ingestion/energistics/witsml-parser/gc-energistics:v0.27.0"
          }
        }
      }

      # ✅ FRONTEND NODES: Deploying of the actual OSDU microservices starts here (will run on frontend nodes due to global nodeSelector)
      gc_entitlements_deploy = {
        enabled = true
        data = {
          bootstrapServiceAccountName = "bootstrap-sa"
          adminUserEmail              = "osdu-admin@service.local"
          airflowComposerEmail        = "airflow@service.local"
        }
      }

      gc_config_deploy = {
        enabled = true
      }

      gc-crs-catalog-deploy = {
        enabled = true
        data = {
          serviceAccountName = "crs-catalog"
        }
      }

      gc_dataset_deploy = {
        enabled = true
        data = {
          serviceAccountName = "dataset"
        }
        conf = {
          postgresSecretName = "dataset-postgres-secret"
        }
      }

      gc-crs-conversion-deploy = {
        enabled = true
      }

      gc_partition_deploy = {
        enabled = true
        data = {
          policyServiceEnabled  = "true"
          edsEnabled            = "false"
          autocompleteEnabled   = "false"
          minioExternalEndpoint = "" # Leave empty for internal MinIO
        }
      }

      gc_policy_deploy = {
        enabled = true
        data = {
          bucketName                  = "refi-opa-policies"
          bootstrapServiceAccountName = "bootstrap-sa"
        }
      }

      gc_storage_deploy = {
        enabled = true
        data = {
          bootstrapServiceAccountName = "bootstrap-sa"
          opaEnabled                  = true
        }
      }

      gc_unit_deploy = {
        enabled = true
      }

      gc_register_deploy = {
        enabled = true
        data = {
          serviceAccountName = "register"
        }
        conf = {
          rabbitmqSecretName         = "rabbitmq-secret"
          registerPostgresSecretName = "register-postgres-secret"
          registerKeycloakSecretName = "register-keycloak-secret"
        }
      }

      gc_notification_deploy = {
        enabled = true
      }

      gc_well_delivery_deploy = {
        enabled = true
      }

      gc_workflow_deploy = {
        enabled = true
        data = {
          sharedTenantName            = "osdu"
          bootstrapServiceAccountName = "bootstrap-sa"
        }
      }

      gc_file_deploy = {
        enabled = true
        data = {
          serviceAccountName = "file"
        }
      }

      gc_schema_deploy = {
        enabled = true
        data = {
          bootstrapServiceAccountName = "bootstrap-sa"
        }
        conf = {
          bootstrapSecretName = "datafier-secret"
          minioSecretName     = "schema-minio-secret"
          postgresSecretName  = "schema-postgres-secret"
          rabbitmqSecretName  = "rabbitmq-secret"
        }
      }

      gc_search_deploy = {
        enabled = true
        data = {
          servicePolicyEnabled = true
        }
      }

      gc_seismic_store_sdms_deploy = {
        enabled = true
        data = {
          redisDdmsHost = "redis-ddms"
        }
      }

      gc_indexer_deploy = {
        enabled = true
        conf = {
          elasticSecretName  = "indexer-elastic-secret"
          keycloakSecretName = "indexer-keycloak-secret"
          rabbitmqSecretName = "rabbitmq-secret"
        }
      }

      gc_legal_deploy = {
        enabled = false
      }

      core_legal_deploy = {
        enabled = true
        data = {
          image                     = "community.opengroup.org:5555/osdu/platform/security-and-compliance/legal/core-plus-legal-master:latest"
          legalStatusUpdateImage    = "community.opengroup.org:5555/osdu/platform/security-and-compliance/legal/core-plus-legal-master:latest"
          imagePullPolicy           = "IfNotPresent"
          cronJobServiceAccountName = "bootstrap-sa"
        }
      }

      gc_wellbore_deploy = {
        enabled = true
      }

      gc_wellbore_worker_deploy = {
        enabled = true
      }

      gc_secret_deploy = {
        enabled = true
      }

      gc_eds_dms_deploy = {
        enabled = true
      }

      gc_oetp_client_deploy = {
        enabled = false
      }

      gc_oetp_server_deploy = {
        enabled = false
      }

      dfaas_tests = {
        enabled = false
      }
    })
  ]
  timeout           = 1200
  wait              = true
  dependency_update = true
  depends_on = [
    aws_eks_addon.osdu-ir-csi-addon,
    null_resource.update_kubeconfig,
    null_resource.label_default_namespace,
    helm_release.istio_ingressgateway
  ]
}

# resource "helm_release" "osdu-ir-install" {
#   name      = "osdu-ir-install"
#   chart     = "${path.module}/charts/osdu-gc-baremetal-0.27.2.tgz"
#   version   = "0.27.2"
#   namespace = "default"
#   lifecycle {
#     ignore_changes = [description]
#   }

#   values = [
#     yamlencode({

#       airflow = {
#         enabled          = true
#         fullnameOverride = "airflow"
#         postgresql = {
#           enabled = false
#         }
#         externalDatabase = {
#           host     = "postgresql-db"
#           user     = "airflow_owner"
#           password = "admin123"
#           database = "airflow"
#         }
#         rbac = {
#           create = true
#         }
#         serviceaccount = {
#           create = true
#         }
#         ingress = {
#           enabled = false
#         }
#         auth = {
#           username = "admin"
#           password = "admin123"
#         }
#         dags = {
#           existingConfigmap = "dags-config"
#         }
#         worker = {
#           extraEnvVarsCM     = "airflow-config"
#           extraEnvVarsSecret = "airflow-secret"
#           podAnnotations = {
#             "sidecar.istio.io/inject" = "false"
#           }
#           automountServiceAccountToken = true
#         }
#         web = {
#           extraEnvVarsCM     = "airflow-config"
#           extraEnvVarsSecret = "airflow-secret"
#           resources = {
#             requests = {
#               cpu    = "500m"
#               memory = "1024Mi"
#             }
#             limits = {
#               cpu    = "750m"
#               memory = "1536Mi"
#             }
#           }
#         }
#         scheduler = {
#           extraEnvVarsCM     = "airflow-config"
#           extraEnvVarsSecret = "airflow-secret"
#           resources = {
#             requests = {
#               cpu    = "500m"
#               memory = "512Mi"
#             }
#             limits = {
#               cpu    = "750m"
#               memory = "1024Mi"
#             }
#           }
#         }
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         tolerations = [
#           {
#             key      = "role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       istio = {
#         gateway = "istio-ingressgateway"
#       }

#       global = {
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         dataPartitionId = "osdu"
#         domain          = local.istio_gateway_domain
#         #domain        = "ae490a26db4054424af33224a83dc6d2-1413201501.us-east-1.elb.amazonaws.com"
#         onPremEnabled = true
#         useHttps      = false # making this true will require us to install the tsl certificates mentione in domain.tls
#         limitsEnabled = true
#         logLevel      = "ERROR"
#       }

#       domain = {
#         # These certificates must be installed when we change to global.useHttps = true.
#         tls = {
#           osduCredentialName     = "osdu-ingress-tls"
#           minioCredentialName    = "minio-ingress-tls"
#           s3CredentialName       = "s3-ingress-tls"
#           keycloakCredentialName = "keycloak-ingress-tls"
#           airflowCredentialName  = "airflow-ingress-tls"
#         }
#       }

#       conf = {
#         createSecrets = true
#         nameSuffix    = ""
#       }

#       minio = {
#         mode             = "standalone"
#         enabled          = true
#         fullnameOverride = "minio"
#         statefulset = {
#           replicaCount  = 1
#           drivesPerNode = 4
#         }
#         auth = {
#           rootUser     = "minio"
#           rootPassword = "admin123"
#         }
#         persistence = {
#           enabled      = true
#           size         = "20Gi"
#           storageClass = "gp2"
#           mountPath    = "/bitnami/minio/data" # FIXME: delete it after MinIO chart update
#         }
#         extraEnvVarsCM       = "minio-config"
#         useInternalServerUrl = false
#         nodeSelector = {
#           "node-role" = "osdu-backend"
#         }
#         tolerations = [
#           {
#             key      = "role"
#             operator = "Equal"
#             value    = "osdu-backend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       rabbitmq = {
#         enabled          = true
#         fullnameOverride = "rabbitmq"
#         auth = {
#           username = "rabbitmq"
#           password = "admin123"
#         }
#         replicaCount = 1
#         loadDefinition = {
#           enabled        = true
#           existingSecret = "load-definition"
#         }
#         logs          = "-"
#         configuration = <<-EOT
#       ## Username and password
#       ##
#       default_user = rabbitmq
#       ## Clustering
#       cluster_name = rabbitmq
#       cluster_formation.peer_discovery_backend  = rabbit_peer_discovery_k8s
#       cluster_formation.k8s.host = kubernetes.default
#       cluster_formation.k8s.address_type = hostname
#       cluster_formation.k8s.service_name = rabbitmq-headless
#       cluster_formation.k8s.hostname_suffix = .rabbitmq-headless.default.svc.cluster.local      
#       cluster_formation.node_cleanup.interval = 10
#       cluster_formation.node_cleanup.only_log_warning = true
#       cluster_partition_handling = autoheal
#       load_definitions = /app/load_definition.json
#       # queue master locator
#       queue_master_locator = min-masters
#       # enable guest user
#       loopback_users.guest = false
#       # log level setup
#       log.connection.level = error
#       log.default.level = error
#     EOT
#         nodeSelector = {
#           "node-role" = "osdu-backend"
#         }
#         tolerations = [
#           {
#             key      = "role"
#             operator = "Equal"
#             value    = "osdu-backend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       postgresql = {
#         enabled          = true
#         fullnameOverride = "postgresql-db"

#         global = {
#           postgresql = {
#             auth = {
#               postgresPassword = "admin123"
#               database         = "postgres"
#             }
#           }
#         }

#         primary = {
#           persistence = {
#             enabled      = true
#             size         = "20Gi"
#             storageClass = "gp2"
#           }
#           resourcesPreset = "medium"
#         }

#         nodeSelector = {
#           "node-role" = "osdu-backend"
#         }

#         tolerations = [
#           {
#             key      = "role"
#             operator = "Equal"
#             value    = "osdu-backend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       elasticsearch = {
#         enabled          = true
#         fullnameOverride = "elasticsearch"

#         security = {
#           enabled         = true
#           elasticPassword = "admin123"
#           tls = {
#             autoGenerated = true
#           }
#         }

#         master = {
#           fullnameOverride = "elasticsearch"
#           masterOnly       = false
#           heapSize         = "1024m"
#           replicas         = "1"
#           persistence = {
#             size         = "10Gi"
#             storageClass = "gp2"
#           }
#         }

#         coordinating = {
#           replicas = "0"
#         }

#         data = {
#           replicas = "1"
#           persistence = {
#             size         = "30Gi"
#             storageClass = "gp2"
#           }
#         }

#         ingest = {
#           replicas = "0"
#         }

#         nodeSelector = {
#           "node-role" = "osdu-backend"
#         }

#         tolerations = [
#           {
#             key      = "role"
#             operator = "Equal"
#             value    = "osdu-backend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       keycloak = {
#         enabled          = true
#         fullnameOverride = "keycloak"

#         auth = {
#           adminPassword = "admin123"
#         }

#         service = {
#           type = "ClusterIP"
#         }

#         postgresql = {
#           enabled = false
#         }

#         externalDatabase = {
#           existingSecret            = "keycloak-database-secret"
#           existingSecretPasswordKey = "KEYCLOAK_DATABASE_PASSWORD"
#           existingSecretHostKey     = "KEYCLOAK_DATABASE_HOST"
#           existingSecretPortKey     = "KEYCLOAK_DATABASE_PORT"
#           existingSecretUserKey     = "KEYCLOAK_DATABASE_USER"
#           existingSecretDatabaseKey = "KEYCLOAK_DATABASE_NAME"
#         }

#         proxy = "none" # This value will become proxy="edge" when global.useHttps = true

#         nodeSelector = {
#           "node-role" = "osdu-istio-keycloak"
#         }

#         tolerations = [
#           {
#             key      = "role"
#             operator = "Equal"
#             value    = "osdu-istio-keycloak"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       bootstrap = {
#         airflow = {
#           dagImages = {
#             csv_parser  = "community.opengroup.org:5555/osdu/platform/data-flow/ingestion/csv-parser/csv-parser/gc-csv-parser:v0.27.0"
#             segy_to_zgy = "community.opengroup.org:5555/osdu/platform/data-flow/ingestion/segy-to-zgy-conversion/gc-segy-to-zgy:v0.27.2"
#             open_vds    = "community.opengroup.org:5555/osdu/platform/domain-data-mgmt-services/seismic/open-vds/openvds-ingestion:3.4.5"
#             energistics = "community.opengroup.org:5555/osdu/platform/data-flow/ingestion/energistics/witsml-parser/gc-baremetal-energistics:v0.27.0"
#           }
#           username = "admin"
#           password = "admin123"
#         }

#         postgres = {
#           external           = false
#           cloudSqlConnection = ""

#           keycloak = {
#             host     = "postgresql-db"
#             port     = "5432"
#             name     = "keycloak"
#             user     = "keycloak_owner"
#             password = "admin123"
#           }

#           dataset = {
#             host     = "postgresql-db"
#             port     = "5432"
#             name     = "dataset"
#             user     = "dataset"
#             password = "admin123"
#           }

#           entitlements = {
#             host     = "postgresql-db"
#             port     = "5432"
#             name     = "entitlements"
#             user     = "entitlements"
#             password = "admin123"
#             schema   = "entitlements_osdu_1"
#           }

#           file = {
#             host     = "postgresql-db"
#             port     = "5432"
#             name     = "file"
#             user     = "file_owner"
#             password = "admin123"
#           }

#           legal = {
#             host     = "postgresql-db"
#             port     = "5432"
#             name     = "legal"
#             user     = "legal_owner"
#             password = "admin123"
#           }

#           partition = {
#             host     = "postgresql-db"
#             port     = "5432"
#             name     = "partition"
#             user     = "partition"
#             password = "admin123"
#           }

#           register = {
#             host     = "postgresql-db"
#             port     = "5432"
#             name     = "register"
#             user     = "register_owner"
#             password = "admin123"
#           }

#           schema = {
#             host     = "postgresql-db"
#             port     = "5432"
#             name     = "schema"
#             user     = "schema"
#             password = "admin123"
#           }

#           seismic = {
#             host     = "postgresql-db"
#             port     = "5432"
#             name     = "seismic"
#             user     = "seismic"
#             password = "admin123"
#           }

#           storage = {
#             host     = "postgresql-db"
#             port     = "5432"
#             name     = "storage"
#             user     = "storage_owner"
#             password = "admin123"
#           }

#           well_delivery = {
#             host     = "postgresql-db"
#             port     = "5432"
#             name     = "well-delivery"
#             user     = "well_delivery_owner"
#             password = "admin123"
#           }

#           wellbore = {
#             host     = "postgresql-db"
#             port     = "5432"
#             name     = "wellbore"
#             user     = "wellbore"
#             password = "admin123"
#           }

#           workflow = {
#             host             = "postgresql-db"
#             port             = "5432"
#             name             = "workflow"
#             user             = "workflow"
#             password         = "admin123"
#             system_namespace = "osdu"
#           }

#           secret = {
#             postgresqlUser = "postgres"
#             postgresqlPort = "5432"
#           }
#         }

#         elastic = {
#           secret = {
#             elasticHost        = "elasticsearch"
#             elasticPort        = "9200"
#             elasticAdmin       = "elastic"
#             elasticSearchUser  = "search-service"
#             elasticIndexerUser = "indexer-service"
#           }
#           imagePullSecrets = []
#         }

#         minio = {
#           external    = false
#           console_url = ""
#           api_url     = ""

#           policy = {
#             user     = "admin"
#             password = "admin123"
#           }

#           airflow = {
#             user     = "admin"
#             password = "admin123"
#           }

#           file = {
#             user     = "admin"
#             password = "admin123"
#           }

#           legal = {
#             user     = "admin"
#             password = "admin123"
#           }

#           storage = {
#             user     = "admin"
#             password = "admin123"
#           }

#           seismicStore = {
#             user     = "admin"
#             password = "admin123"
#             bucket   = ""
#           }

#           schema = {
#             user     = "admin"
#             password = "admin123"
#           }

#           wellbore = {
#             user     = "admin"
#             password = "admin123"
#           }

#           dag = {
#             user     = "admin"
#             password = "admin123"
#           }
#         }

#         keycloak = {
#           secret = {
#             keycloakService   = "http://keycloak"
#             keycloakRealmName = "osdu"
#           }
#         }
#       }

#       gc_baremetal_infra_bootstrap = {
#         enabled = true
#       }

#       rabbitmq_bootstrap = {
#         enabled = true
#         data = {
#           rabbitmqHost                = "rabbitmq" # matches fullnameOverride
#           rabbitmqVhost               = "/"
#           bootstrapServiceAccountName = "bootstrap-sa"
#         }
#       }

#       # This entire block is not required because these are Google Cloud Platform related params. Hence enabled=false
#       # Dont make enabled = true.
#       gc_infra_bootstrap = {
#         enabled = false
#         data = {
#           projectId          = ""
#           serviceAccountName = "infra-bootstrap"
#         }
#         airflow = {
#           bucket          = ""
#           environmentName = ""
#           location        = ""
#           dagImages = {
#             csv_parser  = "community.opengroup.org:5555/osdu/platform/data-flow/ingestion/csv-parser/csv-parser/gc-csv-parser:v0.27.0"
#             segy_to_zgy = "community.opengroup.org:5555/osdu/platform/data-flow/ingestion/segy-to-zgy-conversion/gc-segy-to-zgy:v0.27.2"
#             open_vds    = "community.opengroup.org:5555/osdu/platform/domain-data-mgmt-services/seismic/open-vds/openvds-ingestion:3.4.5"
#             energistics = "community.opengroup.org:5555/osdu/platform/data-flow/ingestion/energistics/witsml-parser/gc-energistics:v0.27.0"
#           }
#         }
#       }

#       # Deploying of the actual OSDU microservices starts here
#       gc_entitlements_deploy = {
#         enabled = true
#         data = {
#           bootstrapServiceAccountName = "bootstrap-sa"
#           adminUserEmail              = "osdu-admin@service.local"
#           airflowComposerEmail        = "airflow@service.local"
#         }
#       }

#       gc_config_deploy = {
#         enabled = true
#       }

#       gc-crs-catalog-deploy = {
#         enabled = true
#         data = {
#           serviceAccountName = "crs-catalog"
#         }
#       }

#       gc_dataset_deploy = {
#         enabled = true
#         data = {
#           serviceAccountName = "dataset"
#         }
#         conf = {
#           postgresSecretName = "dataset-postgres-secret"
#         }
#       }

#       gc-crs-conversion-deploy = {
#         enabled = true
#       }

#       gc_partition_deploy = {
#         enabled = true
#         data = {
#           policyServiceEnabled  = "true"
#           edsEnabled            = "false"
#           autocompleteEnabled   = "false"
#           minioExternalEndpoint = "" # Leave empty for internal MinIO
#         }
#       }

#       gc_policy_deploy = {
#         enabled = true
#         data = {
#           bucketName                  = "refi-opa-policies"
#           bootstrapServiceAccountName = "bootstrap-sa"
#         }
#       }

#       gc_storage_deploy = {
#         enabled = true
#         data = {
#           bootstrapServiceAccountName = "bootstrap-sa"
#           opaEnabled                  = true
#         }
#       }

#       gc_unit_deploy = {
#         enabled = true
#       }

#       gc_register_deploy = {
#         enabled = true
#         data = {
#           serviceAccountName = "register"
#         }
#         conf = {
#           rabbitmqSecretName         = "rabbitmq-secret"
#           registerPostgresSecretName = "register-postgres-secret"
#           registerKeycloakSecretName = "register-keycloak-secret"
#         }
#       }

#       gc_notification_deploy = {
#         enabled = true
#       }

#       gc_well_delivery_deploy = {
#         enabled = true
#       }

#       gc_workflow_deploy = {
#         enabled = true
#         data = {
#           sharedTenantName            = "osdu"
#           bootstrapServiceAccountName = "bootstrap-sa"
#         }
#       }

#       gc_file_deploy = {
#         enabled = true
#         data = {
#           serviceAccountName = "file"
#         }
#       }

#       gc_schema_deploy = {
#         enabled = true
#         data = {
#           bootstrapServiceAccountName = "bootstrap-sa"
#         }
#         conf = {
#           bootstrapSecretName = "datafier-secret"
#           minioSecretName     = "schema-minio-secret"
#           postgresSecretName  = "schema-postgres-secret"
#           rabbitmqSecretName  = "rabbitmq-secret"
#         }
#       }

#       gc_search_deploy = {
#         enabled = true
#         data = {
#           servicePolicyEnabled = true
#         }
#       }

#       gc_seismic_store_sdms_deploy = {
#         enabled = true
#         data = {
#           redisDdmsHost = "redis-ddms"
#         }
#       }

#       gc_indexer_deploy = {
#         enabled = true
#         conf = {
#           elasticSecretName  = "indexer-elastic-secret"
#           keycloakSecretName = "indexer-keycloak-secret"
#           rabbitmqSecretName = "rabbitmq-secret"
#         }
#       }

#       gc_legal_deploy = {
#         enabled = false
#       }

#       core_legal_deploy = {
#         enabled = true
#         data = {
#           image                     = "community.opengroup.org:5555/osdu/platform/security-and-compliance/legal/core-plus-legal-master:latest"
#           legalStatusUpdateImage    = "community.opengroup.org:5555/osdu/platform/security-and-compliance/legal/core-plus-legal-master:latest"
#           imagePullPolicy           = "IfNotPresent"
#           cronJobServiceAccountName = "bootstrap-sa"
#         }
#       }

#       gc_wellbore_deploy = {
#         enabled = true
#       }

#       gc_wellbore_worker_deploy = {
#         enabled = true
#       }

#       gc_secret_deploy = {
#         enabled = true
#       }

#       gc_eds_dms_deploy = {
#         enabled = true
#       }

#       gc_oetp_client_deploy = {
#         enabled = false
#       }

#       gc_oetp_server_deploy = {
#         enabled = false
#       }

#       dfaas_tests = {
#         enabled = false
#       }
#     })
#   ]
#   timeout           = 1200
#   wait              = true
#   dependency_update = true
#   depends_on = [
#     aws_eks_addon.osdu-ir-csi-addon,
#     null_resource.update_kubeconfig,
#     null_resource.label_default_namespace,
#     helm_release.istio_ingressgateway
#   ]
# }


# output "domain-name" {
#   value      = local.istio_gateway_domain
#   depends_on = [helm_release.istio_ingressgateway]
# }

# output "istio_gateway_dns" {
#   value      = data.kubernetes_service.istio_gateway.status[0].load_balancer[0].ingress[0].hostname
#   depends_on = [helm_release.istio_ingressgateway]
# }

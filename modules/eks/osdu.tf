

# # Get Istio LoadBalancer information
# # data "kubernetes_service" "istio_ingress" {
# #   metadata {
# #     name      = "istio-ingress"
# #     namespace = "istio-gateway"
# #   }
# # }

# # locals {
# #   istio_hostname = try(data.kubernetes_service.istio_ingress.status.0.load_balancer.0.ingress.0.hostname, "")
# # }

# ################################################################################################################

# # OSDU Baremetal Helm Installation


# resource "helm_release" "osdu-baremetal" {
#   name      = "osdu-baremetal"
#   chart     = "${path.module}/helm_osdu/osdu-gc-baremetal"
#   version   = "0.27.2"
#   namespace = "default"

#   dependency_update = true

#   # Increased timeout for complex OSDU deployment
#   timeout = 1800  # 30 minutes (OSDU can take 15-20 minutes to deploy)
  
#   # Enable atomic deployment (rollback on failure)
#   atomic = true
  
#   # Wait for all resources to be ready
#   wait = true

#   lifecycle {
#     ignore_changes = [description]
#   }

#   values = [
#     file("${path.module}/helm_osdu/custom-values.yaml")
#   ]

#   depends_on = [
#     # Ensure Istio is fully installed and configured
#     helm_release.istio_base,
#     helm_release.istiod,
#     helm_release.istio_ingress,
    
#     # Ensure default namespace is labeled for sidecar injection
#     null_resource.label_default_namespace,
    
#     # Ensure Istio ingress service is available
#     # data.kubernetes_service.istio_ingress
#   ]
# }


# ###############################################################################################################

resource "helm_release" "osdu_baremetal" {
  name       = "osdu-baremetal"
  repository = "oci://community.opengroup.org:5555/osdu/platform/deployment-and-operations/infra-gcp-provisioning/gc-helm"
  chart      = "osdu-gc-baremetal"
  namespace  = "default"
  timeout    = 1800  # 30 minutes
  wait       = true

  # This reads your custom-values.yaml file
  # Use the custom-values.yaml file from the same directory as this tf file
  values = [
    file("${path.module}/helm_osdu/custom-value.yaml")
  ]

}




# resource "helm_release" "osdu-ir-install" {
#   name      = "osdu-ir-install"
#   chart     = "${path.module}/helm_osdu/osdu-gc-baremetal"
#   version   = "0.27.2"
#   namespace = "default"
#   lifecycle {
#     ignore_changes = [description]
#   }

#   values = [
#     yamlencode({

#       # Global tolerations for all pods
#       tolerations = [
#         {
#           key      = "node-role"
#           operator = "Equal"
#           value    = "osdu-backend"
#           effect   = "NoSchedule"
#         },
#         {
#           key      = "node-role"
#           operator = "Equal"
#           value    = "osdu-frontend"
#           effect   = "NoSchedule"
#         },
#         {
#           key      = "node-role"
#           operator = "Equal"
#           value    = "osdu-istio-keycloak"
#           effect   = "NoSchedule"
#         }
#       ]

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
#           nodeSelector = {
#             "node-role" = "osdu-frontend"
#           }
#           tolerations = [
#             {
#               key      = "node-role"
#               operator = "Equal"
#               value    = "osdu-frontend"
#               effect   = "NoSchedule"
#             }
#           ]
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
#           nodeSelector = {
#             "node-role" = "osdu-frontend"
#           }
#           tolerations = [
#             {
#               key      = "node-role"
#               operator = "Equal"
#               value    = "osdu-frontend"
#               effect   = "NoSchedule"
#             }
#           ]
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
#           nodeSelector = {
#             "node-role" = "osdu-frontend"
#           }
#           tolerations = [
#             {
#               key      = "node-role"
#               operator = "Equal"
#               value    = "osdu-frontend"
#               effect   = "NoSchedule"
#             }
#           ]
#         }
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       istio = {
#         gateway = "osdu-ir-istio-gateway"
#       }

#       global = {
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         dataPartitionId = "osdu"
#         domain        = "ae490a26db4054424af33224a83dc6d2-1413201501.us-east-1.elb.amazonaws.com"
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

#       # OPA Service - Frontend
#       opa = {
#         enabled = true
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       # Redis Services - All on backend nodes
#       redis-dataset = {
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

#       redis-entitlements = {
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

#       redis-indexer = {
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

#       redis-notification = {
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

#       redis-search = {
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

#       redis-seismic-store = {
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

#       redis-storage = {
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

#       # Redis master for OSDU - Backend
#       osdu-ir-install-redis-master = {
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

#         # Bootstrap Jobs - Schedule on backend nodes
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

#       rabbitmq_bootstrap = {
#         enabled = true
#         data = {
#           rabbitmqHost                = "rabbitmq"
#           rabbitmqVhost               = "/"
#           bootstrapServiceAccountName = "bootstrap-sa"
#         }
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

#       gc_entitlements_deploy = {
#         enabled = true
#         data = {
#           bootstrapServiceAccountName = "bootstrap-sa"
#           adminUserEmail              = "osdu-admin@service.local"
#           airflowComposerEmail        = "airflow@service.local"
#         }
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       gc_config_deploy = {
#         enabled = true
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       gc-crs-catalog-deploy = {
#         enabled = true
#         data = {
#           serviceAccountName = "crs-catalog"
#         }
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       gc_dataset_deploy = {
#         enabled = true
#         data = {
#           serviceAccountName = "dataset"
#         }
#         conf = {
#           postgresSecretName = "dataset-postgres-secret"
#         }
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       gc-crs-conversion-deploy = {
#         enabled = true
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       gc_partition_deploy = {
#         enabled = true
#         data = {
#           policyServiceEnabled  = "true"
#           edsEnabled            = "false"
#           autocompleteEnabled   = "false"
#           minioExternalEndpoint = ""
#         }
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       gc_policy_deploy = {
#         enabled = true
#         data = {
#           bucketName                  = "refi-opa-policies"
#           bootstrapServiceAccountName = "bootstrap-sa"
#         }
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       gc_storage_deploy = {
#         enabled = true
#         data = {
#           bootstrapServiceAccountName = "bootstrap-sa"
#           opaEnabled                  = true
#         }
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       gc_unit_deploy = {
#         enabled = true
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
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
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       gc_notification_deploy = {
#         enabled = true
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       gc_well_delivery_deploy = {
#         enabled = true
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       gc_workflow_deploy = {
#         enabled = true
#         data = {
#           sharedTenantName            = "osdu"
#           bootstrapServiceAccountName = "bootstrap-sa"
#         }
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       gc_file_deploy = {
#         enabled = true
#         data = {
#           serviceAccountName = "file"
#         }
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
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
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       gc_search_deploy = {
#         enabled = true
#         data = {
#           servicePolicyEnabled = true
#         }
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       gc_seismic_store_sdms_deploy = {
#         enabled = true
#         data = {
#           redisDdmsHost = "redis-ddms"
#         }
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       gc_indexer_deploy = {
#         enabled = true
#         conf = {
#           elasticSecretName  = "indexer-elastic-secret"
#           keycloakSecretName = "indexer-keycloak-secret"
#           rabbitmqSecretName = "rabbitmq-secret"
#         }
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }

#      tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       gc_legal_deploy = {
#         enabled = false
#       }

#       core_legal_deploy = {
#         enabled = true
#         data = {
#           image                     = "community.opengroup.org:5555/osdu/platform/security-and-compliance/legal/core-plus-legal-master:latest"
#           imagePullPolicy           = "IfNotPresent"
#           cronJobServiceAccountName = "bootstrap-sa"
#         }
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
#         /*data = {
#           cronJobServiceAccountName = "bootstrap-sa"
#           image = {
#             repository = "community.opengroup.org:5555/osdu/platform/security-and-compliance/legal/core-plus-legal-master"
#             tag        = "latest"
#           }
#         }*/
#       }

#       gc_wellbore_deploy = {
#         enabled = true
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       gc_wellbore_worker_deploy = {
#         enabled = true
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       gc_secret_deploy = {
#         enabled = true
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       gc_eds_dms_deploy = {
#         enabled = true
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       gc_oetp_client_deploy = {
#         enabled = false
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       gc_oetp_server_deploy = {
#         enabled = false
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }

#       dfaas_tests = {
#         enabled = false
#         nodeSelector = {
#           "node-role" = "osdu-frontend"
#         }
#         tolerations = [
#           {
#             key      = "node-role"
#             operator = "Equal"
#             value    = "osdu-frontend"
#             effect   = "NoSchedule"
#           }
#         ]
#       }
#     })
#   ]
#   timeout           = 1200
#   wait              = true
#   dependency_update = true
  
# }


# output "domain-name" {
#   value = local.istio_gateway_domain
# }

/*resource "helm_release" "osdu-legal" {
  name      = "osdu-legal"
  chart     = "${path.module}/charts/osdu-gc-baremetal/charts/core-plus-legal-deploy"
  namespace = "default"

  values = [
    yamlencode({
      data = {
        image                     = "community.opengroup.org:5555/osdu/platform/security-and-compliance/legal/core-plus-legal-master:latest"
        imagePullPolicy           = "IfNotPresent"
        cronJobServiceAccountName = "bootstrap-sa"
      }

      conf = {
        configmap           = "legal-config"
        appName             = "legal"
        minioSecretName     = "legal-minio-secret"
        postgresSecretName  = "legal-postgres-secret"
        rabbitmqSecretName  = "rabbitmq-secret"
        bootstrapSecretName = "datafier-secret"
        replicas            = 1
      }

      istio = {
        proxyCPU         = "5m"
        proxyCPULimit    = "500m"
        proxyMemory      = "50Mi"
        proxyMemoryLimit = "512Mi"
      }
    })
  ]

  depends_on = [
    aws_eks_addon.osdu-ir-csi-addon,
    null_resource.label_default_namespace
  ]
}*/

/*resource "helm_release" "osdu-legal" {
  name      = "osdu-legal"
  chart     = "${path.module}/charts/osdu-gc-baremetal/charts/core-plus-legal-deploy"
  namespace = "default"

  values = [
    yamlencode({

      data = {
        image                     = "community.opengroup.org:5555/osdu/platform/security-and-compliance/legal/core-plus-legal-master:latest"
        imagePullPolicy           = "IfNotPresent"
        cronJobServiceAccountName = "bootstrap-sa"
      }

    })
  ]

  depends_on = [
    aws_eks_addon.osdu-ir-csi-addon,
    null_resource.label_default_namespace
  ]
}*/






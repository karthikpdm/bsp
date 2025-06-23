from datetime import timedelta

from osdu_airflow.backward_compatibility.default_args import \
    update_default_args


from kubernetes.client import models as k8s_models
import airflow
from airflow import DAG
from airflow.contrib.operators.kubernetes_pod_operator import \
    KubernetesPodOperator

from osdu_airflow.operators.update_status import UpdateStatusOperator

# default args for airflow
default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': airflow.utils.dates.days_ago(0),
    'retries': 0,
    'retry_delay': timedelta(minutes=5),
    'execution_timeout': timedelta(hours=24),
    'dagrun_timeout': timedelta(hours=24),
}

default_args = update_default_args(default_args)

# Get values from dag run configuration
authorization = "{{ dag_run.conf['authToken'] }}"
sd_svc_token = "{{ dag_run.conf['execution_context']['id_token'] or dag_run.conf['authToken'] }}"
dataPartitionId = "{{ dag_run.conf['execution_context']['data_partition_id'] }}"
run_id = "{{ dag_run.conf['runId'] }}"
sd_svc_api_key = "{{ dag_run.conf['execution_context']['sd_svc_api_key'] }}"
storage_svc_api_key = "{{ dag_run.conf['execution_context']['storage_svc_api_key'] }}"
filecollection_segy_id = "{{ dag_run.conf['execution_context']['filecollection_segy_id'] }}"
work_product_id = "{{ dag_run.conf['execution_context']['work_product_id'] }}"
svc_token = "{{ dag_run.conf['execution_context']['id_token'] or dag_run.conf['authToken'] }}"
user_id = "{{ dag_run.conf['execution_context'].get('userId') }}"
# Constants

DAG_NAME = "Segy_to_zgy_conversion" # Replace it by the workflowName passed on workflow service API.
DOCKER_IMAGE = "{{ var.value.image__segy_to_zgy_converter }}" # Replace it by the segy-to-zgy container
SEGY_CONVERTER = "segy-to-zgy"
DAG_INIT = "dag-init"
NAMESPACE = "default"
K8S_POD_KWARGS = {
            "container_resources": k8s_models.V1ResourceRequirements(
                limits={
                    "memory": airflow.models.Variable.get("zgy__ingestion__limit__memory", default_var="1Gi"),
                    "cpu": airflow.models.Variable.get("zgy__ingestion__limit__cpu", default_var="1000m")
                },
                requests={
                    "memory": airflow.models.Variable.get("zgy__ingestion__request__memory", default_var="1Gi"),
                    "cpu": airflow.models.Variable.get("zgy__ingestion__request__cpu", default_var="200m")
                }
            )
            ,
            "startup_timeout_seconds": 300,
            "annotations": {
                "sidecar.istio.io/inject": "false"
            }
        }
if not K8S_POD_KWARGS:
    K8S_POD_KWARGS = {}

# Values to pass to csv parser
params = ["--osdu", filecollection_segy_id, work_product_id ]

# Get environment variables
env_vars = {
    "STORAGE_SVC_URL": "{{ var.value.core__service__storage__url }}",
    "SD_SVC_URL": "{{ var.value.core__service__seismic__url }}",
    "SD_SVC_TOKEN": sd_svc_token,
    "STORAGE_SVC_TOKEN": authorization,
    "STORAGE_SVC_API_KEY": storage_svc_api_key,
    "SD_SVC_API_KEY": sd_svc_api_key,    
    "OSDU_DATAPARTITIONID": dataPartitionId,
    "SD_READ_CACHE_PAGE_SIZE": "4195024",
    "SD_READ_CACHE_MAX_PAGES": "16",
    "SEGYTOZGY_VERBOSITY": "3",
    "SEGYTOZGY_GENERATE_INDEX": "1",
    "USER_ID": user_id
}
env_vars.update({'S3_ENDPOINT_OVERRIDE': '{{ var.value.core__service__minio__url }}'})

with DAG(
    DAG_NAME, 
    default_args=default_args,
    schedule_interval=None
) as dag:
    update_status_running = UpdateStatusOperator(
        task_id="update_status_running",
    )

    segytozgy_converter = KubernetesPodOperator(
        namespace=NAMESPACE,
        task_id=SEGY_CONVERTER,
        name=SEGY_CONVERTER,
        env_vars=env_vars,
        arguments=params,
        is_delete_operator_pod=True,
        image=DOCKER_IMAGE,
        **K8S_POD_KWARGS
    )

    update_status_finished = UpdateStatusOperator(
        task_id="update_status_finished",
        trigger_rule="all_done"
    )

update_status_running >> segytozgy_converter >> update_status_finished # pylint: disable=pointless-statement
#@ Version: 0.27.2
#@ Branch: v0.27.2
#@ Commit: 940d56de
#@ SHA-256 checksum: be0f9641387b8b92902fb26e264b19a18ed47ca1767cd91379a4448041483200

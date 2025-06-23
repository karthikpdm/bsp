from datetime import timedelta
from json import dumps

import os

from kubernetes.client import models as k8s_models
import airflow
from airflow import DAG
from airflow.contrib.operators.kubernetes_pod_operator import KubernetesPodOperator
from osdu_airflow.backward_compatibility.default_args import update_default_args
from osdu_airflow.operators.update_status import UpdateStatusOperator

# default args for airflow
default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': airflow.utils.dates.days_ago(0),
    'email': ['airflow@example.com'],
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

default_args = update_default_args(default_args)

# Get values from dag run configuration
record_id = "{{ dag_run.conf['execution_context']['id'] }}"
authorization = "{{ dag_run.conf['authToken'] }}"
dataPartitionId = "{{ dag_run.conf['execution_context']['dataPartitionId'] }}"
run_id = "{{ dag_run.conf['run_id'] }}"
data_service_to_use = "{{ dag_run.conf['execution_context'].get('data_service_to_use', 'file') }}"
steps = ["LOAD_FROM_CSV", "TYPE_COERCION", "ID", "ACL", "LEGAL", "KIND", "META", "TAGS", "UNIT", "CRS", "RELATIONSHIP", "STORE_TO_OSDU"]
user_id = "{{ dag_run.conf['execution_context'].get('userId') }}"

# Constants
DAG_NAME = "csv_ingestion"
DOCKER_IMAGE = "{{ var.value.image__csv_parser }}"
NAMESPACE = "default"
CSV_PARSER = "csv-parser"

# Values to pass to csv parser
params = {
    "id": record_id,
    "authorization": authorization,
    "dataPartitionId": dataPartitionId,
    "steps": steps,
    "dataServiceName": "{{ dag_run.conf['execution_context'].get('data_service_to_use', 'file') }}",
    "userId":user_id
}

# Get environment variables
# TODO: put env vars here from application.properties
env_vars = {
            "storage_service_endpoint": "{{ var.value.core__service__storage__url }}",
            "schema_service_endpoint": "{{ var.value.core__service__schema__url }}",
            "search_service_endpoint": "{{ var.value.core__service__search__url }}",
            "partition_service_endpoint": "{{ var.value.core__service__partition__url }}",
            "unit_service_endpoint": "{{ var.value.core__service__unit__url }}",
            "file_service_endpoint": "{{ var.value.core__service__file__url }}",
            "dataset_service_endpoint": "{{ var.value.core__service__dataset__url }}",
            "workflow_service_endpoint": "{{ var.value.core__service__workflow__url }}",
            "data_service_to_use": "file",
            "OPENID_PROVIDER_CLIENT_ID": os.getenv("KEYCLOAK_CLIENT_ID"),
            "OPENID_PROVIDER_CLIENT_SECRET": os.getenv("KEYCLOAK_CLIENT_SECRET"),
            "OPENID_PROVIDER_URL": os.getenv("CSV_PARSER_KEYCLOAK_AUTH_URL")
        }
if data_service_to_use:
    env_vars["data_service_to_use"] = data_service_to_use

operator_kwargs = { "container_resources": k8s_models.V1ResourceRequirements(
                limits={
                    "memory": airflow.models.Variable.get("csv__ingestion__limit__memory", default_var="1Gi"),
                    "cpu": airflow.models.Variable.get("csv__ingestion__limit__cpu", default_var="1000m")
                },
                requests={
                    "memory": airflow.models.Variable.get("csv__ingestion__request__memory", default_var="1Gi"),
                    "cpu": airflow.models.Variable.get("csv__ingestion__request__cpu", default_var="200m"),
                }
            ),
            "annotations": {
                "sidecar.istio.io/inject": "false"
            },
            "startup_timeout_seconds": 300,
            "cmds": [
                "sh",
                "-c",
                'java -Djava.security.egd=file:/dev/./urandom  ' \
                ' -Dspring.profiles.active=anthos '  \
                '-jar /app/csv-parser-gc.jar \'{"id": "{{ dag_run.conf[\'execution_context\'][\'id\'] }}", "authorization": "{{ dag_run.conf[\'authToken\'] }}", "dataPartitionId": "{{ dag_run.conf[\'execution_context\'][\'dataPartitionId\'] }}", "steps": ["LOAD_FROM_CSV", "TYPE_COERCION", "ID", "ACL", "LEGAL", "KIND", "META", "TAGS", "UNIT", "CRS", "RELATIONSHIP", "STORE_TO_OSDU"], "dataServiceName": "{{ dag_run.conf[\'execution_context\'].get(\'data_service_to_use\', \'file\') }}"}\''
            ]
        }

with DAG(
    DAG_NAME,
    default_args=default_args,
    schedule_interval=None
) as dag:
    update_status_running = UpdateStatusOperator(
        task_id="update_status_running",
    )

    csv_parser = KubernetesPodOperator(
        namespace=NAMESPACE,
        task_id=CSV_PARSER,
        name=CSV_PARSER,
        env_vars=env_vars,
        arguments=[dumps(params)],
        is_delete_operator_pod=True,
        image=DOCKER_IMAGE,
        **operator_kwargs)

    update_status_finished = UpdateStatusOperator(
        task_id="update_status_finished",
        trigger_rule="all_done"
    )

update_status_running >> csv_parser >> update_status_finished # pylint: disable=pointless-statement
#@ Version: 0.27.0
#@ Branch: v0.27.0
#@ Commit: 0507bd21
#@ SHA-256 checksum: 12a9c0d83fc72f14baaa5ce76be0dc6ec9a76c0e072466328dbd117b3a41a353

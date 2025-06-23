#  Copyright 2022 Google LLC
#  Copyright 2022 EPAM Systems
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

"""Energistics XML ingest."""

from datetime import timedelta

import os

from kubernetes.client import models as k8s_models
import airflow
from airflow import DAG
from airflow.contrib.operators.kubernetes_pod_operator import KubernetesPodOperator
from osdu_airflow.backward_compatibility.default_args import update_default_args
from osdu_airflow.operators.ensure_manifest_integrity import EnsureManifestIntegrityOperator
from osdu_airflow.operators.process_manifest_r3 import ProcessManifestOperatorR3
from osdu_airflow.operators.validate_manifest_schema import ValidateManifestSchemaOperator
from osdu_airflow.operators.update_status import UpdateStatusOperator

PROCESS_SINGLE_MANIFEST_FILE = "process_single_manifest_file_task"
PROCESS_BATCH_MANIFEST_FILE = "batch_upload"
ENSURE_INTEGRITY_TASK = "provide_manifest_integrity_task"
SINGLE_MANIFEST_FILE_FIRST_OPERATOR = "validate_manifest_schema_task"

dag_name = "Energistics_xml_ingest"
docker_image = "{{ var.value.image__witsml_parser }}"
k8s_namespace = "default"
env_vars = {
    "CLOUD_PROVIDER": "baremetal",
    "OSDU_ANTHOS_STORAGE_URL": "{{ var.value.core__service__storage__url }}",
    "OSDU_ANTHOS_DATASET_URL": "{{ var.value.core__service__dataset__url }}",
    "OSDU_ANTHOS_DATA_PARTITION": "{{ dag_run.conf['execution_context']['Payload']['data-partition-id'] }}",
    "KEYCLOAK_AUTH_URL": os.getenv("KEYCLOAK_AUTH_URL"),
    "KEYCLOAK_CLIENT_ID": os.getenv("KEYCLOAK_CLIENT_ID"),
    "KEYCLOAK_CLIENT_SECRET": os.getenv("KEYCLOAK_CLIENT_SECRET"),
    "MINIO_ENDPOINT": os.getenv("MINIO_ENDPOINT"),
    "MINIO_ACCESS_KEY": os.getenv("MINIO_ACCESS_KEY"),
    "MINIO_SECRET_KEY": os.getenv("MINIO_SECRET_KEY")
}

k8s_pod_operator_kwargs = {
    "container_resources": k8s_models.V1ResourceRequirements(
        limits={
            "memory": airflow.models.Variable.get("witsml__ingestion__limit__memory", default_var="8Gi"),
            "cpu": airflow.models.Variable.get("witsml__ingestion__limit__cpu", default_var="1000m")
        },
        requests={
            "memory": airflow.models.Variable.get("witsml__ingestion__request__memory", default_var="1Gi"),
            "cpu": airflow.models.Variable.get("witsml__ingestion__request__cpu", default_var="200m")
        }
    ),
    "annotations": {
        "sidecar.istio.io/inject": "false"
    }
}

default_args = {
    "name": dag_name,
    "owner": "energistics",
    "start_date": airflow.utils.dates.days_ago(0),
    "retries": 0,
    "retry_delay": timedelta(minutes=50),
    "trigger_rule": "none_failed",
}

default_args = update_default_args(default_args)

dag = DAG(
    "Energistics_xml_ingest",
    default_args=default_args,
    description="witsml parser dag",
    schedule_interval=None,
    dagrun_timeout=timedelta(minutes=60)
)

with dag:
    update_status_running_op = UpdateStatusOperator(
        task_id="update_status_running_task",
    )

    update_status_finished_op = UpdateStatusOperator(
        task_id="update_status_finished_task",
        trigger_rule="all_done"
    )

    process_energistics_op = KubernetesPodOperator(
        namespace=k8s_namespace,
        task_id="witsml_parser_task",
        name="witsml_parser_task",
        do_xcom_push=True,
        image=docker_image,
        env_vars=env_vars,
        cmds=[
            "sh",
            "-c",
            "mkdir -p /airflow/xcom/; "
            "python main.py"
            " --context '{{ dag_run.conf['execution_context'] | tojson }}'"
            " --file_service {{ var.value.core__service__file__host }}"
            " --out /airflow/xcom/return.json",
        ],
        is_delete_operator_pod=True,
        image_pull_policy="Always",
        get_logs=True,
        startup_timeout_seconds=300,
        **k8s_pod_operator_kwargs,
    )

    validate_schema_operator = ValidateManifestSchemaOperator(
        task_id="validate_manifest_schema_task",
        previous_task_id=process_energistics_op.task_id,
        trigger_rule="none_failed_or_skipped"
    )

    ensure_integrity_op = EnsureManifestIntegrityOperator(
        task_id=ENSURE_INTEGRITY_TASK,
        previous_task_id=validate_schema_operator.task_id,
        trigger_rule="none_failed_or_skipped"
    )

    process_single_manifest_file = ProcessManifestOperatorR3(
        task_id=PROCESS_SINGLE_MANIFEST_FILE,
        previous_task_id=ensure_integrity_op.task_id,
        trigger_rule="none_failed_or_skipped"
    )

update_status_running_op >> \
process_energistics_op >> \
validate_schema_operator >> \
ensure_integrity_op >> \
process_single_manifest_file >> \
update_status_finished_op
# @ Version: 0.27.0
# @ Branch: v0.27.0
# @ Commit: 1e188016
# @ SHA-256 checksum: c912f496a3bb7b67c9d0b2fcc666bb982abdfac47bdea815452783fc6e0a698c

#  Copyright 2020 Google LLC
#  Copyright 2020 EPAM Systems
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

"""DAG for R3 ingestion."""

from datetime import timedelta

import airflow
from airflow import DAG
from airflow.models import Variable
from airflow.operators.dummy_operator import DummyOperator
from airflow.operators.python_operator import BranchPythonOperator
from osdu_airflow.backward_compatibility.default_args import update_default_args
from osdu_airflow.operators.ensure_manifest_integrity_by_reference import EnsureManifestIntegrityOperatorByReference
from osdu_airflow.operators.process_manifest_r3_by_reference import ProcessManifestOperatorR3ByReference
from osdu_airflow.operators.update_status_by_reference import UpdateStatusOperatorByReference
from osdu_airflow.operators.validate_manifest_schema_by_reference import ValidateManifestSchemaOperatorByReference
from osdu_ingestion.libs.exceptions import NotOSDUSchemaFormatError

BATCH_NUMBER = int(Variable.get("core__ingestion__batch_count", "3"))
PROCESS_SINGLE_MANIFEST_FILE = "process_single_manifest_file_task"
PROCESS_BATCH_MANIFEST_FILE = "batch_upload"
ENSURE_INTEGRITY_TASK = "provide_manifest_integrity_task"
SINGLE_MANIFEST_FILE_FIRST_OPERATOR = "validate_manifest_schema_task"


default_args = {
    "start_date": airflow.utils.dates.days_ago(0),
    "retries": 0,
    "retry_delay": timedelta(seconds=30),
    "trigger_rule": "none_failed",
}

default_args = update_default_args(default_args)

workflow_name = "Osdu_ingest_by_reference"


def is_batch(**context):
    """
    :param context: Dag context
    :return: SubDag to be executed next depending on Manifest type
    """
    manifest = context["dag_run"].conf["execution_context"].get("manifest")

    if isinstance(manifest, dict): 
        subdag = SINGLE_MANIFEST_FILE_FIRST_OPERATOR
    elif isinstance(manifest, str): # str for manifest rec id
        subdag = SINGLE_MANIFEST_FILE_FIRST_OPERATOR
        context["ti"].xcom_push(key="manifest_ref_ids", value=[manifest])
    elif isinstance(manifest, list):
        subdag = PROCESS_BATCH_MANIFEST_FILE
    else:
        raise NotOSDUSchemaFormatError(f"Manifest must be either 'dict' or 'list'. "
                                       f"Got {manifest}.")
    return subdag


with DAG(
    workflow_name,
    default_args=default_args,
    description="R3 manifest processing with providing integrity",
    schedule_interval=None,
    dagrun_timeout=timedelta(minutes=60)
) as dag:
    update_status_running_op = UpdateStatusOperatorByReference(
        task_id="update_status_running_task",
    )

    branch_is_batch_op = BranchPythonOperator(
        task_id="check_payload_type",
        python_callable=is_batch,
        trigger_rule="none_failed_or_skipped"
    )

    update_status_finished_op = UpdateStatusOperatorByReference(
        task_id="update_status_finished_task",
        dag=dag,
        trigger_rule="all_done",
    )

    validate_schema_operator = ValidateManifestSchemaOperatorByReference(
        task_id="validate_manifest_schema_task",
        trigger_rule="none_failed_or_skipped"
    )

    ensure_integrity_op = EnsureManifestIntegrityOperatorByReference(
        task_id=ENSURE_INTEGRITY_TASK,
        previous_task_id=validate_schema_operator.task_id,
        trigger_rule="none_failed_or_skipped"
    )

    process_single_manifest_file = ProcessManifestOperatorR3ByReference(
        task_id=PROCESS_SINGLE_MANIFEST_FILE,
        previous_task_id=ensure_integrity_op.task_id,
        trigger_rule="none_failed_or_skipped"
    )

    # Dummy operator as entry point into parallel task of batch upload
    batch_upload = DummyOperator(
        task_id=PROCESS_BATCH_MANIFEST_FILE
    )

    for batch in range(0, BATCH_NUMBER):
        batch_upload >> ProcessManifestOperatorR3ByReference(
            task_id=f"process_manifest_task_{batch + 1}",
            previous_task_id=f"provide_manifest_integrity_task_{batch + 1}",
            batch_number=batch + 1,
            trigger_rule="none_failed_or_skipped"
        ) >> update_status_finished_op

update_status_running_op >> branch_is_batch_op  # pylint: disable=pointless-statement
branch_is_batch_op >> batch_upload  # pylint: disable=pointless-statement
branch_is_batch_op >> validate_schema_operator >> ensure_integrity_op >> process_single_manifest_file >> update_status_finished_op  # pylint: disable=pointless-statement

#@ Version: 0.27.0
#@ Branch: v0.27.0
#@ Commit: 0adc4346
#@ SHA-256 checksum: d16ff9fc7351415bcea7cbd7ba7ebf0d85a29c4240b0f17b223d9c594f8127a7

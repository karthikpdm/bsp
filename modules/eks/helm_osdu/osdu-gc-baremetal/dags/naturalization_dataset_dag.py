"""This DAG file is to handle Naturalization functionality """

import logging
from datetime import timedelta

from airflow import DAG
from airflow.operators.dummy_operator import DummyOperator
from airflow.operators.python_operator import PythonOperator
from airflow.utils.dates import days_ago
from airflow.utils.task_group import TaskGroup
from airflow.utils.trigger_rule import TriggerRule
from osdu_airflow.eds.eds_ingest.data_fetcher.data_fetcher import DataFetcher
from osdu_airflow.eds.eds_naturalization.naturalization_of_dataset import Naturalization
from osdu_airflow.eds.eds_naturalization.update_wpc_records import UpdateWPCRecord
from osdu_airflow.eds.eds_scheduler.naturalization_email_notification import (
    NaturaliztionEmail,
)

logger = logging.getLogger(__name__)

default_args = {
    "owner": "airflow",
    "depends_on_past": False,
    "start_date": days_ago(1),
    "retries": 1,
    "retry_delay": timedelta(minutes=1),
}

dag = DAG(
    "eds_naturalization",
    default_args=default_args,
    description="Parallel execution of TaskGroups without SubDagOperator",
    # Do not schedule the DAG periodically, we will trigger it manually
    schedule_interval=None,
)


def fetch_wpc_record(id_set, task_instance, **context):
    """function to fetch wpc record from the fetch_wpc_record function"""

    list_of_dataset_ids = context["ti"].xcom_pull(key="batches")[id_set]
    wpc_log = {}
    datset_id_dict = {}
    wpc_log_fetch = {}
    file_size_log = {}
    naturalization_obj = Naturalization()
    for list_of_wpc_ids in list_of_dataset_ids:
        if all(isinstance(item, dict) for item in list_of_dataset_ids):
            wpc_id, path = list_of_wpc_ids["id"], list_of_wpc_ids["path"]
            wpc_log[wpc_id], wpc_log_fetch[wpc_id], file_size_log[wpc_id] = (
                naturalization_obj.naturalization(wpc_id, path)
            )
        else:
            wpc_id = list_of_wpc_ids
            wpc_log[wpc_id], wpc_log_fetch[wpc_id], file_size_log[wpc_id] = (
                naturalization_obj.naturalization(wpc_id, None)
            )

        datset_id_dict[wpc_id] = wpc_log[wpc_id]
    task_instance.xcom_push(key=f"WPC_Data{id_set}", value=wpc_log)
    task_instance.xcom_push(key=f"dataset_{id_set}", value=datset_id_dict)
    task_instance.xcom_push(key=f"WPC_LOG{id_set}", value=wpc_log_fetch)
    task_instance.xcom_push(key=f"Storage{id_set}", value=file_size_log)


# Create a DummyOperator as a placeholder for generating batches


def generate_id_batches(all_id_sets, batch_size):
    """function to create batches to execute in parallel"""
    num_tasks = 4
    batch_size = len(all_id_sets) // num_tasks
    remaining_ids = len(all_id_sets) % num_tasks

    batches = []
    start_idx = 0

    for i in range(num_tasks):
        end_idx = start_idx + batch_size + (1 if i < remaining_ids else 0)
        batches.append(all_id_sets[start_idx:end_idx])
        start_idx = end_idx

    return batches


# Task to generate batches dynamically


def generate_batches_task(task_instance, **kwargs):
    """Function to divide the ids among the four parallel tasks"""
    # Define the desired batch size
    batch_size = 2
    input_dag = kwargs["dag_run"].conf.get("execution_context")

    if "work_product_component_data" in input_dag:
        all_id_sets = input_dag["work_product_component_data"]
    else:
        all_id_sets = input_dag["id"]
    # Generate batches of ID sets
    id_sets_batches = generate_id_batches(all_id_sets, batch_size)
    task_instance.xcom_push(key="batches", value=id_sets_batches)
    return id_sets_batches


def update_status(task_instance, **context):
    """Function to update the wpc ids using storage API."""
    wpc_updated_data = []
    file_generic_id_dict = {}
    wpc_file_generic_ids = {}

    for wpc_increment in range(4):
        wpc_data = context["ti"].xcom_pull(key=f"WPC_Data{wpc_increment}")
        file_generic_id_dict = context["ti"].xcom_pull(key=f"dataset_{wpc_increment}")
        wpc_record = context["ti"].xcom_pull(key=f"WPC_LOG{wpc_increment}")
        if wpc_data and isinstance(wpc_data, dict) and file_generic_id_dict:
            for wpc_id, dataset_id in file_generic_id_dict.items():
                wpc_data_dataset = wpc_record[wpc_id]
                wpc_data_dataset["data"]["Datasets"].clear()
                wpc_data_dataset["data"]["Datasets"].extend(dataset_id)
                wpc_updated_data.append(wpc_data_dataset)
                wpc_file_generic_ids[wpc_data_dataset["id"]] = dataset_id

    if wpc_updated_data:
        update_wpc_record = UpdateWPCRecord()
        update_wpc_record.update_wpc_records(wpc_updated_data)
        task_instance.xcom_push(
            key="Sucessfully Naturalized ID", value=wpc_file_generic_ids
        )


def trigger_email_notification(task_instance, **context):
    """Function to send email notification."""
    try:
        dag_run_id = context["dag_run"].run_id
        start_date = context["dag_run"].start_date
        end_date = context["dag_run"].end_date

        data_rows = []

        for wpc_increment in range(4):
            wpc_xcom_logs = context["ti"].xcom_pull(key=f"WPC_LOG{wpc_increment}")
            file_generic_id_dict = context["ti"].xcom_pull(
                key=f"dataset_{wpc_increment}"
            )
            success_record = context["ti"].xcom_pull(key=f"Sucessfully Naturalized ID")
            storage_utilized = context["ti"].xcom_pull(key=f"Storage{wpc_increment}")

            for wpc_id, dataset_id in file_generic_id_dict.items():
                wpc_record = wpc_xcom_logs[wpc_id]
                datasets = wpc_record["data"]["Datasets"]
                total_dataset_count = len(wpc_record["data"]["Datasets"])
                success_record_count = len(success_record[wpc_id])
                total_storage_utilized = sum(storage_utilized[wpc_id])
                failed_record_count = total_dataset_count - success_record_count

                if total_dataset_count == success_record_count:
                    status = "Success"
                elif total_dataset_count == failed_record_count:
                    status = "Fail"
                else:
                    status = "Partial Success"

                row = {
                    "Dag Run ID": dag_run_id,
                    "Start Time": start_date,
                    "End Time": end_date,
                    "Status": status,
                    "WPC ID": wpc_id,
                    "Success Count": total_dataset_count,
                    "Failed Count": failed_record_count,
                    "Total Count": total_dataset_count,
                    "Datasets": datasets,
                    "Total Size": total_storage_utilized,
                }
                data_rows.append(row)

        naturalization_email = NaturaliztionEmail()
        naturalization_email.eds_email_notification_execution(data_rows, dag_run_id)

    except Exception as exp:
        logger.info(f"Exception in Email Notifcation: {exp}.")


# Create a PythonOperator for each batch of ID sets
process_batch_tasks = []
# Create the task to generate batches dynamically
generate_batches_op = PythonOperator(
    task_id="generate_batches_task",
    python_callable=generate_batches_task,
    dag=dag,
)


update_status_task = PythonOperator(
    task_id="update_status_finished_task",
    python_callable=update_status,
    provide_context=True,
    dag=dag,
    trigger_rule="all_done",
)

send_email_notification = PythonOperator(
    task_id="send_email_notification",
    python_callable=trigger_email_notification,
    provide_context=True,
    dag=dag,
    trigger_rule="all_done",
)


start = DummyOperator(task_id="start", dag=dag)
with dag:
    for increment in range(4):
        with TaskGroup(f"Naturalization_{increment}") as process_id_set_group:
            fetch_wpc_task = PythonOperator(
                task_id=f"fetch_wpc_cs.g_upload_data_task_{increment}",
                python_callable=fetch_wpc_record,
                op_args=[increment],
                dag=dag,
                trigger_rule=TriggerRule.NONE_FAILED,
            )
            fetch_wpc_task

            (
                start
                >> generate_batches_op
                >> process_id_set_group
                >> update_status_task
                >> send_email_notification
            )

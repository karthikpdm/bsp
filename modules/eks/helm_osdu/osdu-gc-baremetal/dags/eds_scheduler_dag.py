"""
M19 python file to create Dag eds_scheduler and its tasks
"""
from airflow import DAG
from airflow.operators.python_operator import PythonOperator
from airflow.utils.dates import days_ago
from osdu_airflow.eds.eds_ingest.utilities.airflow_utility import \
    AirflowUtility
from osdu_airflow.eds.eds_scheduler.eds_email_automation import EmailAutomation
from osdu_airflow.eds.eds_scheduler.scheduler_trigger_dagrun import \
    SchedulerTriggerDagRunOperator

airflow_utility=AirflowUtility()
#dynamic scheduler interval variable
scheduler_interval_time = airflow_utility.scheduler_interval()


def email_template():
    """
        Function to call the email automation
    """
    email_obj = EmailAutomation()
    return email_obj.eds_email_automation_execution()

default_args = {
    "owner": "airflow",
    "depends_on_past": False,
    "start_date": days_ago(0),
    "email": ["airflow@example.com"],
    "email_on_failure": False,
    "email_on_retry": False,
}


with DAG(
        "eds_scheduler",
        description = "",
        default_args = default_args,
        schedule_interval = scheduler_interval_time,
        catchup = False,
        tags = ["external_data_workflow"]
) as dag:
    trigger_eds_ingest = SchedulerTriggerDagRunOperator(
        task_id = "trigger_eds_ingest",
        trigger_dag_id = "eds_ingest",
    )
    send_email_notification = PythonOperator(
           task_id = "send_email",
           provide_context = True,
           python_callable = email_template,
    )

    trigger_eds_ingest >> send_email_notification

#@ Version: 0.27.0
#@ Branch: v0.27.0
#@ Commit: 656ebe00
#@ SHA-256 checksum: 96c6d1899a2cd6456a1ad0ab7ad84919ac0e575b2aa043dddb46e912b054bc54

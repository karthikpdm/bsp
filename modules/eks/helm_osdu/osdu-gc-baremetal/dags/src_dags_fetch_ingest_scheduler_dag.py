"""
     M24 DAG file for airflow which is the starting point for the eds_ingest DAG
"""
from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.python_operator import PythonOperator
from osdu_airflow.eds.eds_ingest.constants import Constant
from osdu_airflow.eds.eds_ingest.src_dags_fetch_and_ingest import \
    FetchAndIngest

default_args = {
    "owner": "airflow",
    "start_date": datetime.today() - timedelta(days=1)
}


def _ingest(task_instance, **kwargs):
    """
       Accepts JSON as input where fetch kind, fetch filter and
       External Data Source Endpoint details are available
    """
    input_params = kwargs["dag_run"].conf.get("execution_context")
    eds_ingest_run_id = kwargs["dag_run"].run_id
    fetch_and_ingest = FetchAndIngest()
    status = fetch_and_ingest.fetch_and_ingest(input_params,eds_ingest_run_id)
    if Constant.MESSAGE  in status:
        # display output/exception message in Airlow xcom window
        task_instance.xcom_push(key= Constant.EXCEPTION, value=status[Constant.MESSAGE])
    elif isinstance(status,str):
        task_instance.xcom_push(key=Constant.MESSAGE , value=status)
    else:
        task_instance.xcom_push(key="Successfully Ingested record id list",
                                value=status["ingested_record_id"])
        if isinstance(status["ingested_record_id"], list):
            task_instance.xcom_push(key="Successfully Ingested record id count",
                                    value=len(status["ingested_record_id"]))
        task_instance.xcom_push(key="Failed record id list",
                                value=status["failed_record_id"])
        if isinstance(status["failed_record_id"], list):
            task_instance.xcom_push(key="Failed record id count",
                                    value=len(status["failed_record_id"]))
        task_instance.xcom_push(key="reference_error",
                                value=status["reference_error"])
        task_instance.xcom_push(key="Manifest Dag Run ID",
                                value=status["manifest_dag_run_id"])
        task_instance.xcom_push(key="EDS Naturalization DAG Run ID",
                                value = status["eds_naturalization_run_id"])


dag = DAG(
    Constant.EDS_INGEST_DAG_NAME,
    default_args=default_args,
    description="Fetch data from external system and ingest to OSDU platform",
    schedule_interval=timedelta(days=1),
)

fetch_client = PythonOperator(
    task_id= Constant.FETCH_CLIENT,
    python_callable=_ingest,
    provide_context=True,
    dag=dag,
)

#@ Version: 0.27.0
#@ Branch: v0.27.0
#@ Commit: 656ebe00
#@ SHA-256 checksum: eeb6afb47360e267dba78aa6f8d3afc42df5202b5342d0033b9bb4b307dd490c

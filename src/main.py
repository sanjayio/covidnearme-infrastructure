import base64
from google.cloud import storage
from datetime import datetime
import pandas as pd


def upload_blob(destination_bucket, source_file, destination_blob):
  storage_client = storage.Client()
  bucket = storage_client.bucket(destination_bucket)
  blob = bucket.blob(destination_blob)

  blob.upload_from_filename(source_file)


def create_file_name():
  curr_date = datetime.now().strftime("%Y_%m_%d_%H_%M_%S")
  file_name = 'nsw_covid_tests_results_' + curr_date + '.csv'
  return file_name


def download_file_from_url(file_name):
  df = pd.read_csv('https://data.nsw.gov.au/data/dataset/aefcde60-3b0c-4bc0-9af1-6fe652944ec2/resource/5d63b527-e2b8-4c42-ad6f-677f14433520/download/confirmed_cases_table1_location_agg.csv')
  df.to_csv('/tmp/' + file_name, encoding='utf-8')

def entrypoint(event, context):
  file_name = create_file_name()
  download_file_from_url(file_name)
  destination_bucket = 'skio-datasets'
  source_file = '/tmp/' + file_name
  upload_blob(destination_bucket, source_file, file_name)

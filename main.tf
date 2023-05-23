terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.51.0"
    }
  }
}

provider "google" {
  credentials = file("./keys/service_account.json")

  project = "skio-playground"
  region  = "australia-southeast1"
  zone    = "australia-southeast1-a"
}

data "archive_file" "source" {
    type        = "zip"
    source_dir  = "./src"
    output_path = "./dist/function.zip"
}

resource "random_id" "bucket_prefix" {
  byte_length = 8
}

resource "google_storage_bucket" "covidnearmebucket" {
  name          = "${random_id.bucket_prefix.hex}-covidnearme-bucket"
  location      = "australia-southeast1"
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "covidnearmefunctionarchive" {
  name   = "src-${data.archive_file.source.output_md5}.zip"
  bucket = google_storage_bucket.covidnearmebucket.name
  source = data.archive_file.source.output_path
  content_type = "application/zip"
  depends_on   = [
    google_storage_bucket.covidnearmebucket,
    data.archive_file.source
  ]
}

resource "google_pubsub_topic" "covidnearmetopic" {
  name = "covidnearme-pubsub-topic-${random_id.bucket_prefix.hex}"
}

resource "google_cloudfunctions2_function" "covidnearmefunction" {
  name        = "covidnearme-fetch-function-${random_id.bucket_prefix.hex}"
  description = "Covidnearme fetch function"
  location    = "australia-southeast1"

  build_config {
    runtime     = "python38"
    entry_point = "entrypoint"
    environment_variables = {
      BUILD_CONFIG_TEST = "build_test"
    }
    source {
      storage_source {
        bucket = google_storage_bucket.covidnearmebucket.name
        object = google_storage_bucket_object.covidnearmefunctionarchive.name
      }
    }
  }

  service_config {
    max_instance_count = 3
    min_instance_count = 1
    available_memory   = "512M"
    timeout_seconds    = 60
    environment_variables = {
      SERVICE_CONFIG_TEST = "config_test"
    }
    ingress_settings               = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email          = "skio-playground-personal-mac@skio-playground.iam.gserviceaccount.com"
  }

  event_trigger {
    trigger_region = "australia-southeast1"
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.covidnearmetopic.id
    retry_policy   = "RETRY_POLICY_RETRY"
  }
}

resource "google_cloud_scheduler_job" "covidnearmeschedule" {
  name        = "covidnearme-schedule"
  description = "Schedule for covidnearme fetch"
  schedule    = "0 10 * * FRI"

  pubsub_target {
    # topic.id is the topic's full resource name.
    topic_name = google_pubsub_topic.covidnearmetopic.id
    data       = base64encode("trigger")
  }
}

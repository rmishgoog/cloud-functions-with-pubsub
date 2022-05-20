provider "google-beta" {
  project = var.project
  region  = var.region
}

resource "google_project_service" "enabled_services" {
  project            = var.project
  service            = each.key
  for_each           = toset(["cloudfunctions.googleapis.com", "vpcaccess.googleapis.com", "cloudbuild.googleapis.com", "compute.googleapis.com", "pubsub.googleapis.com"])
  disable_on_destroy = false

}

resource "google_storage_bucket" "source_code_bucket" {
  project                     = var.project
  uniform_bucket_level_access = true
  name                        = "functions-${var.project}"
  location                    = "US"
}

#Define the archive for the http function code
resource "google_storage_bucket_object" "http_function_archive" {
  name         = "go-http-function-archive"
  bucket       = google_storage_bucket.source_code_bucket.name
  source       = "../user-facing-cloud-function/go-http-function.zip"
  content_type = "application/zip"
}

#Define the archive for the webhook/trigger function code
resource "google_storage_bucket_object" "go_trigger_function_archive" {
  name         = "go-trigger-function-archive"
  bucket       = google_storage_bucket.source_code_bucket.name
  source       = "../pubsub-event-trigger/go-trigger-function.zip"
  content_type = "application/zip"
}

#Create service account for http function
resource "google_service_account" "http_go_function_service_account" {
  project      = var.project
  account_id   = var.service_account_http_fn
  display_name = "http function custom service account"
}

#Create service account for pub/sub trigger function
resource "google_service_account" "trigger_go_function_service_account" {
  project      = var.project
  account_id   = var.service_account_trigger_fn
  display_name = "trigger function custom service account"
}

#Cloud function to recieve http request
resource "google_cloudfunctions_function" "http_go_function" {
  name                  = "go-http-function"
  region                = var.region
  description           = "A basic Go HTTP function to accept POST HTTP request and publish to Pub/Sub"
  runtime               = "go116"
  project               = var.project
  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.source_code_bucket.name
  source_archive_object = google_storage_bucket_object.http_function_archive.name
  trigger_http          = true
  entry_point           = "AcceptInvites"
  environment_variables = {
    PUBSUB_TOPIC_ID      = google_pubsub_topic.invites_topic.name,
    GOOGLE_CLOUD_PROJECT = var.project
  }
  service_account_email = google_service_account.http_go_function_service_account.email
}

#Cloud function to recieve pub/sub events
resource "google_cloudfunctions_function" "http_trigger_function" {
  name                  = "go-trigger-function"
  region                = var.region
  description           = "A basic Go HTTP function to be invoked as a HTTP trigger when event is published into Pub/Sub"
  runtime               = "go116"
  project               = var.project
  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.source_code_bucket.name
  source_archive_object = google_storage_bucket_object.go_trigger_function_archive.name
  ingress_settings      = "ALLOW_INTERNAL_ONLY"
  entry_point           = "RegisterInvite"
  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource = google_pubsub_topic.invites_topic.id
    failure_policy {
      retry = false
    }
  }
  service_account_email = google_service_account.trigger_go_function_service_account.email
}

resource "google_cloudfunctions_function_iam_member" "http_go_function_invoker" {
  region         = google_cloudfunctions_function.http_go_function.region
  project        = google_cloudfunctions_function.http_go_function.project
  cloud_function = google_cloudfunctions_function.http_go_function.name
  role           = "roles/cloudfunctions.invoker"
  member         = "user:${var.invoker}"
}

resource "google_pubsub_topic" "invites_topic" {
  name                       = "invites-main-topic"
  project                    = var.project
  message_retention_duration = "86600s"
}

resource "google_pubsub_topic_iam_member" "invites_topic_publisher" {
  project = google_pubsub_topic.invites_topic.project
  topic   = google_pubsub_topic.invites_topic.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.http_go_function_service_account.email}"
}
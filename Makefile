PROJECT := $(shell gcloud config get-value project)
APP := urly-wurly
IMAGE := gcr.io/${PROJECT}/${APP}
BUCKET := ${APP}-links
DOMAIN := urly-wurly-oyehxjlgwa-uc.a.run.app

storage:
	gsutil mb gs://${BUCKET}

build:
	gcloud builds submit container/ --tag ${IMAGE}

cicd:
	gcloud projects add-iam-policy-binding ${PROJECT} \
		--member serviceAccount:396559029476@cloudbuild.gserviceaccount.com \
		--role roles/editor
	gcloud beta run services add-iam-policy-binding \
		--region=us-central1 --member=allUsers \
		--role=roles/run.invoker ${APP}
	gcloud builds submit \
		--config ci/cloudbuild.yaml \
		--substitutions=_APP="${APP}",_DOMAIN="${DOMAIN}",_BUCKET="${BUCKET}"

deploy:
	gcloud beta run deploy ${APP} \
		--allow-unauthenticated \
	  --image ${IMAGE} \
		--region us-central1 \
		--set-env-vars=DOMAIN=${DOMAIN},PROJECT=${PROJECT},BUCKET=${BUCKET}

meta-data:
	gcloud beta run services describe ${APP}

all: storage build deploy

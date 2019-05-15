PROJECT := $(shell gcloud config get-value project)
OWNER := $(shell gcloud config get-value account | sed -e 's/@/_at_/' | sed -e 's/\./_dot_/g')
APP := urly-wurly
IMAGE := gcr.io/${PROJECT}/${APP}
BUCKET := ${APP}-links
DOMAIN := urly-wurly-oyehxjlgwa-uc.a.run.app

storage:
	gsutil mb gs://${BUCKET}

labels:
	gsutil label ch -l project:${APP} gs://${BUCKET}
	gsutil label ch -l owner:${OWNER} gs://${BUCKET}
	gsutil label ch -l approver:not-set gs://${BUCKET}

build:
	gcloud builds submit container/ --tag ${IMAGE}

cicd:
	gcloud projects add-iam-policy-binding ${PROJECT} \
		--member serviceAccount:396559029476@cloudbuild.gserviceaccount.com \
		--role roles/editor
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

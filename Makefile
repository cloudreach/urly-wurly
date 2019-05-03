PROJECT := $(shell gcloud config get-value project)
APP := urly-wurly
IMAGE := gcr.io/${PROJECT}/${APP}
BUCKET := ${APP}-links
DOMAIN := urly-wurly-oyehxjlgwa-uc.a.run.app

storage:
	gsutil mb gs://${BUCKET}

build:
	gcloud builds submit container/ --tag ${IMAGE}

deploy:
	gcloud config set run/region us-central1
	gcloud beta run deploy ${APP} \
		--allow-unauthenticated \
	  --image ${IMAGE} \
		--set-env-vars=DOMAIN=${DOMAIN},PROJECT=${PROJECT},BUCKET=${BUCKET}

meta-data:
	gcloud beta run services describe ${APP}

all: storage build deploy

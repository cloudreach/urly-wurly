PROJECT := $(shell gcloud config get-value project)
IMAGE := gcr.io/${PROJECT}/urly-wurly
BUCKET := urly-wurly-links
DOMAIN := urly-wurly-p53dlhmcna-uc.a.run.app

storage:
	gsutil mb gs://${BUCKET}

build:
	gcloud builds submit container/ --tag ${IMAGE}

deploy:
	gcloud config set run/region us-central1
	gcloud beta run deploy urly-wurly \
		--allow-unauthenticated \
	  --image ${IMAGE} \
		--set-env-vars=DOMAIN=${DOMAIN},PROJECT=${PROJECT},BUCKET=${BUCKET}

meta-data:
	gcloud beta run services describe urly-wurly

all: storage build deploy

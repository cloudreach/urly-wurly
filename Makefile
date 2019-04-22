GCP_ID := $(shell gcloud config get-value project)
IMAGE := "gcr.io/${GCP_ID}/run-service"

package:
	gcloud auth configure-docker
	docker build container/ -t ${IMAGE}
	docker push ${IMAGE}

deploy:
	gcloud config set run/region us-central1
	gcloud beta run deploy run-service --allow-unauthenticated --image ${IMAGE} 


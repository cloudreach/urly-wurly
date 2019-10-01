import * as pulumi from "@pulumi/pulumi";
import * as gcp from "@pulumi/gcp";

const config = new pulumi.Config();

const projectName = process.env.UW_PROJECT_NAME || config.require('project_name');
const projectNumber = process.env.UW_PROJECT_NUMBER || config.require('project_number');
const locationName = process.env.UW_LOCATION || config.require('location');
const domainName = process.env.UW_DOMAIN_NAME || config.require('domain');
const repositoryName = process.env.UW_REPOSITORY_NAME || config.require('repository');
const branchName = process.env.UW_BRANCH_NAME || config.require('branch');

const stageName = process.env.UW_STAGE_NAME || pulumi.getStack();
const appName = process.env.UW_APP_NAME || `urly-wurly-${stageName}`;
const imageName = process.env.UW_IMAGE_NAME || `gcr.io/${projectName}/${appName}`;

const bucket = new gcp.storage.Bucket(appName, {
  location: locationName.split('-')[0],
});

const service = new gcp.cloudrun.Service(appName, {
  location: locationName,
  metadata: {
    namespace: projectName,
  },
  spec: {
    containers: [
      {
        image: imageName,
      },
    ],
  },
});

const mapping = new gcp.cloudrun.DomainMapping(appName, {
  location: locationName,
  name: domainName,
  metadata: {
    namespace: projectName,
  },
  spec: {
    routeName: service.name,
  },
});

const pipeline = new gcp.cloudbuild.Trigger(appName, {
  project: projectName,
  triggerTemplate: {
    branchName: branchName,
    repoName: repositoryName,
  },
  description: `Urly-Wurly build pipeline for stage '${stageName}'`,
  substitutions: {
    '_DOMAIN': domainName,
    '_APP': appName,
    '_BUCKET': bucket.name,
  },
  filename: 'ci/cloudbuild.yaml'
});

const pipelineBinding = new gcp.projects.IAMBinding(appName, {
  role: 'roles/editor',
  project: projectName,
  members: [
    `serviceAccount:${projectNumber}@cloudbuild.gserviceaccount.com`,
  ],
});

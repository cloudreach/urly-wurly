init:
	npm i

infrastructure:
	pulumi stack select ${STAGE}
	pulumi up -y

all: init infrastructure 

.PHONY: all init infrastructure

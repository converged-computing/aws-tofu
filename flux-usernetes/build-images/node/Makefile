.PHONY: all
all: init fmt validate build

.PHONY: init
init: 
	packer init .
	
.PHONY: fmt
fmt: 
	packer fmt .

.PHONY: validate
validate: 
	packer validate .
	
.PHONY: build
build: 
	packer build -var region=us-east-1 -var source_ami=ami-0c7217cdde317cfec -var instance_type=m4.large node.pkr.hcl

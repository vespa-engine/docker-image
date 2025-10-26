#!/bin/sh

# this script does the following:
# - build a container image named 'vespaengine/with-cuda'
# - check that nvidia driver module are loaded
# - use nvidia container toolkit (ctk) to generate CDI config
# - start a temporary container
# - generate minimal application using GPU
# - deploy the application inside the container
# - wait for the application to be ready
# - dump the entire vespa log
# - grep for GPU-related output in the same log
# - stop and remove the temporary container
# prerequisites:
# nvidia drivers installed OK
# nvidia container toolkit installed

PATH=/usr/bin:/usr/sbin:/usr/local/bin:/usr/bin:/usr/local/sbin
export PATH

privuid=$(sudo id -u)

if [ "$privuid" != "0" ]; then
	echo "$0 failed: sudo access required"
	exit 1
fi

privrun() { sudo "$@"; }
traceprun() { echo "# $*"; privrun "$@"; }
checkprun() {
	if traceprun "$@"; then :; else
		echo "FAILED"
		exit 1
	fi
}
rundnf() { checkprun dnf -y "$@"; }

if [ -f /usr/bin/docker ]; then
	conman=docker
elif [ -f /usr/bin/podman ]; then
	conman=podman
else
	echo "Could not find 'docker' or 'podman'"
	exit 1
fi

conrun() { checkprun $conman "$@"; }

disable_selinux() {
	selinux_mode=$(getenforce)
	if [ "$selinux_mode" = "Enforcing" ]; then
		echo "WARNING: selinux mode is $selinux_mode"
		echo "NOTE: you may need to change this permanently; or add your own handling of selinux"
		grep '^SELINUX=' /etc/selinux/config /dev/null 2>/dev/null
		checkprun setenforce Permissive
	fi
}

gen_dockerfile() {
	arch=$(arch)
	if [ "$arch" = "x86_64" ]; then
		nvarch=$arch
	elif [ "$arch" = "aarch64" ]; then
		nvarch=sbsa
	else
		echo "Unknown CPU arch: '$arch'"
		exit 1
	fi
	sed "s/%{nvarch}/${nvarch}/" >> Dockerfile.with-cuda << 'EOF'
FROM docker.io/vespaengine/vespa:latest
USER root
RUN dnf -y install 'dnf-command(config-manager)'
RUN dnf -y config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel8/%{nvarch}/cuda-rhel8.repo
RUN dnf -y install $(rpm -q --queryformat '%{NAME}-cuda-%{VERSION}' vespa-onnxruntime)
USER vespa
EOF
}

disable_selinux
gen_dockerfile
conrun build -t vespaengine/with-cuda -f Dockerfile.with-cuda .
rm -f Dockerfile.with-cuda

checkprun nvidia-modprobe

traceprun nvidia-ctk system create-device-nodes
traceprun nvidia-ctk runtime configure --enable-cdi

privrun mkdir -p /etc/cdi
checkprun nvidia-ctk cdi generate --device-name-strategy=type-index --format=json --output /etc/cdi/nvidia.json
privrun chmod 644 /etc/cdi/nvidia.json

podname=vespa-test-$$-tmp
conrun run --device nvidia.com/gpu=all --detach --name ${podname} --hostname ${podname} vespaengine/with-cuda
rundnf install zip
(cd app && zip -r ../application.zip *)
conrun cp application.zip ${podname}:/tmp
conrun exec -it ${podname} sh -c 'cd /tmp && vespa deploy --wait 300 application.zip; vespa-logfmt -N; vespa-logfmt -N | grep -i gpu'
traceprun nvidia-smi
conrun stop ${podname}
conrun rm ${podname}
rm -f application.zip

#!/bin/sh

distro=amzn2023

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

disable_selinux() {
	selinux_mode=$(getenforce)
	if [ "$selinux_mode" = "Enforcing" ]; then
		echo "WARNING: selinux mode is $selinux_mode"
		echo "NOTE: you may need to change this permanently; or add your own handling of selinux"
		grep '^SELINUX=' /etc/selinux/config /dev/null 2>/dev/null
		checkprun setenforce Permissive
	fi
}

# available on amzn2023:
rundnf install docker

disable_selinux
rundnf install pciutils zip
traceprun lspci | grep -i nvidia

if [ -f /usr/bin/docker ]; then
	conman=docker
elif [ -f /usr/bin/podman ]; then
	conman=podman
else
	echo "Could not find 'docker' or 'podman'"
	exit 1
fi

conrun() { checkprun $conman "$@"; }

find_nvarch() {
	arch=$(arch)
	if [ "$arch" = "x86_64" ]; then
		nvarch=$arch
	elif [ "$arch" = "aarch64" ]; then
		nvarch=sbsa
	else
		echo "Unknown CPU arch: '$arch'"
		exit 1
	fi
}

gen_dockerfile() {
	find_nvarch
	sed "s/%{nvarch}/${nvarch}/" >> Dockerfile.with-cuda << 'EOF'
FROM docker.io/vespaengine/vespa:latest
USER root
RUN dnf -y install 'dnf-command(config-manager)'
RUN dnf -y config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel8/%{nvarch}/cuda-rhel8.repo
RUN dnf -y install $(rpm -q --queryformat '%{NAME}-cuda-%{VERSION}' vespa-onnxruntime)
USER vespa
EOF
}

# could be useful maybe:
kernel_version=$(uname -r)
rundnf install kernel-headers-${kernel_version}
rundnf install dkms
find_nvarch
rundnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/${distro}/${nvarch}/cuda-${distro}.repo
rundnf install nvidia-open
checkprun nvidia-modprobe

rundnf config-manager --add-repo https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo
TK_VERSION=1.18.0
rundnf install -y \
	nvidia-container-toolkit-${TK_VERSION} \
	nvidia-container-toolkit-base-${TK_VERSION} \
	libnvidia-container-tools-${TK_VERSION} \
	libnvidia-container1-${TK_VERSION}

traceprun nvidia-ctk system create-device-nodes
traceprun nvidia-ctk runtime configure --enable-cdi

privrun mkdir -p /etc/cdi
checkprun nvidia-ctk cdi generate --device-name-strategy=type-index --format=json --output /etc/cdi/nvidia.json
privrun chmod 644 /etc/cdi/nvidia.json

traceprun systemctl restart $conman

gen_dockerfile
conrun build -t vespaengine/with-cuda -f Dockerfile.with-cuda .
rm -f Dockerfile.with-cuda

podname=vespa-test-$$-tmp
conrun run --device nvidia.com/gpu=all --detach --name ${podname} --hostname ${podname} vespaengine/with-cuda
(cd app && zip -r ../application.zip *)
conrun cp application.zip ${podname}:/tmp
conrun exec -it ${podname} sh -c 'cd /tmp && vespa deploy --wait 300 application.zip; vespa-logfmt -N; vespa-logfmt -N | grep -i gpu'
traceprun nvidia-smi
conrun stop ${podname}
conrun rm ${podname}
rm -f application.zip

exit 0

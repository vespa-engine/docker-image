#!/bin/sh

distro=amzn2023
arch=x86_64

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

selinux_mode=$(getenforce)
if [ "$selinux_mode" = "Enforcing" ]; then
	echo "WARNING: selinux mode is $selinux_mode"
	echo "NOTE: you may need to change this permanently; or add your own handling of selinux"
	grep '^SELINUX=' /etc/selinux/config /dev/null 2>/dev/null
	checkprun setenforce Permissive
fi

rundnf install docker
traceprun systemctl start docker --now

cat >> Dockerfile.with-cuda << EOF
FROM docker.io/vespaengine/vespa:latest
USER root
RUN dnf -y install 'dnf-command(config-manager)'
RUN dnf -y config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel8/${arch}/cuda-rhel8.repo
RUN dnf -y install \$(rpm -q --queryformat '%{NAME}-cuda-%{VERSION}' vespa-onnxruntime)
USER vespa
EOF

checkprun docker build -t vespaengine/with-cuda -f Dockerfile.with-cuda .

rundnf install dkms

rundnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/$distro/$arch/cuda-$distro.repo

privrun systemctl stop google-cloud-ops-agent || echo ignored google-cloud-ops-agent
rundnf install nvidia-open

checkprun nvidia-modprobe

rundnf config-manager --add-repo https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo
TK_VERSION=1.18.0
rundnf install -y \
	nvidia-container-toolkit-${TK_VERSION} \
	nvidia-container-toolkit-base-${TK_VERSION} \
	libnvidia-container-tools-${TK_VERSION} \
	libnvidia-container1-${TK_VERSION}

traceprun nvidia-ctk runtime configure --enable-cdi
traceprun systemctl restart docker
traceprun nvidia-ctk system create-device-nodes
ls -l /dev/nvidia*

makedev() {
	devname="/dev/$1"
	major=$2
	minor=$3
	if [ -e $devname ]; then
		info=$(file $devname)
		if file $devname | grep -q ": character special ($major/$minor)\$"; then
			echo "device OK: $info"
		else
			echo "Wanted '$devname' with major/minor device number '$major/$minor'"
			echo "But got: $info"
			exit 1
		fi
		privrun chmod 666 $devname

	else
		checkprun mknod -Z -m 666 $devname c ${major} ${minor}
		file $devname
	fi
	if [ "$selinux_mode" != "Disabled" ]; then
		privrun chcon -t container_file_t $devname
	fi
}

frontend_major=$(awk '$2 == "nvidia-frontend" || $2 == "nvidia" { print $1 }' < /proc/devices)
if [ "${frontend_major}" = "" ]; then
	echo "FAILED: missing 'nvidia-frontend' in /proc/devices"
	exit 1
fi
makedev nvidiactl ${frontend_major} 255
for i in $(cat /proc/driver/nvidia/gpus/*/information | awk '$2 == "Minor:" { print $3 }'); do
	makedev nvidia${i} ${frontend_major} $i
done
makedev nvidia-modeset ${frontend_major} 254

uvm_major=$(awk '$2 == "nvidia-uvm" { print $1 }' < /proc/devices)
if [ "${uvm_major}" = "" ]; then
	echo "FAILED: missing 'nvidia-uvm' in /proc/devices"
	exit 1
fi
makedev nvidia-uvm       ${uvm_major} 0
makedev nvidia-uvm-tools ${uvm_major} 1

privrun mkdir -p /etc/cdi
checkprun nvidia-ctk cdi generate --device-name-strategy=type-index --format=json --output /etc/cdi/nvidia.json
privrun chmod 644 /etc/cdi/nvidia.json

podname=vespa-test-$$-tmp
checkprun docker run --device nvidia.com/gpu=all --detach --name ${podname} --hostname ${podname} vespaengine/with-cuda
(cd app && zip -r ../application.zip *)
privrun docker cp application.zip ${podname}:/tmp
privrun docker exec -it ${podname} sh -c 'cd /tmp && vespa deploy --wait 300 application.zip && vespa-logfmt -N | grep -i gpu'
privrun docker stop ${podname}
checkprun docker rm ${podname}
rm -f application.zip

set -euxo pipefail

FIRST_MASTER_NAME="$(/usr/share/google/get_metadata_value attributes/dataproc-master)"
NAME="$(/usr/share/google/get_metadata_value name)"
if [[ "${NAME}" == "${FIRST_MASTER_NAME}" ]]; then
    echo "Configuring Knox to redirect the traffic"
    sed -i 's/10001/10000/g' /etc/knox/conf/topologies/sandbox.xml
    sed -i 's/10001/10000/g' /etc/knox/conf/topologies/default.xml

    sudo systemctl restart  knox
fi

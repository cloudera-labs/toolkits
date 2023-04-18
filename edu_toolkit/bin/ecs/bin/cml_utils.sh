#!/bin/bash

set -e # Any subsequent(*) commands which fail will cause the shell script to exit immediately

# Program name
PROG=`basename $0`

run_cmd() {
    cmd="bash -c \"$1\""
    log_info "Running command: ${cmd}"
    bash -c "${cmd}"
}

run_kubectl_cmd() {
    export PATH=$PATH:/var/lib/rancher/rke2/bin/;
    export KUBECONFIG=/etc/rancher/rke2/rke2.yaml;
    run_cmd "$@"
}

log_info() {
    echo "INFO ${1}" 1>&2
}

log_error() {
    error="$1"
    echo "ERROR ${error}" 1>&2
}

subcommand_usage() {
    echo "Usage: ${0}.
    Use this script to perform optional post-install setup actions for CML workspace on ECS Private Cloud.
    Sub-commands:
                help    Print this message
                upload-cert    CML Certificate Upload           -n <namespace> -c <certificate-path> -k <keyfile-path>
                add-docker-registry-credentials  Adds Docker Registry Credentials for CML to fetch custom engines from a secure repository       -n <namespace> -h <docker-server-host> -u <docker--username> -p <docker-password>" 1>&2

}
auto_create_certs() {
    YOUR_DOMAIN_NAME=$1

    CERT_DIR="/tmp/${PROG}/certs"
    run_cmd "mkdir -p ${CERT_DIR}"

    AUTO_GENERATED_KEY_FILE="ssl.key"
    AUTO_GENERATED_CERT_FILE="ssl.crt"

    cat >req.conf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

prompt = no
[req_distinguished_name]
CN = ${YOUR_DOMAIN_NAME}
[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${YOUR_DOMAIN_NAME}
EOF

    # Generate the certificate
    run_cmd "openssl req -new -newkey RSA:2048 -nodes -keyout ${CERT_DIR}/${AUTO_GENERATED_KEY_FILE} -out ${CERT_DIR}/ssl.csr -extensions v3_req -config req.conf"

    # Sign the certificate
    run_cmd "openssl x509 -req -days 365 -in ${CERT_DIR}/ssl.csr -signkey ${CERT_DIR}/ssl.key -out ${CERT_DIR}/${AUTO_GENERATED_CERT_FILE} -extensions v3_req -extfile req.conf"

    # Cleanup
    run_cmd "rm ${CERT_DIR}/ssl.csr"
    export CERT_PATH=${CERT_DIR}/${AUTO_GENERATED_CERT_FILE}
    export KEY_PATH=${CERT_DIR}/${AUTO_GENERATED_KEY_FILE}
}

ml_cert_installation() {

    while getopts "n:c:k:" options
    do
        case ${options} in
            (n)
                K8_NAMESPACE=${OPTARG}
                ;;
            (c)
                CERT_PATH=${OPTARG}
                # Verify that the cert-path actually exists
                if ! [ -f ${CERT_PATH} ]; then
                    log_error "No cert file found at location: ${CERT_PATH}.."
                    exit 1
                fi
                ;;
            (k)
                KEY_PATH=${OPTARG}
                # Verify that the key-path actually exists
                if ! [ -f ${KEY_PATH} ]; then
                    log_error "No key file found at location: ${KEY_PATH}.."
                    exit 1
                fi
                ;;
            (?)
                log_error "Invalid option ${OPTARG} passed .. "
                exit 1
                ;;
        esac
    done

    if [ -z "${K8_NAMESPACE}" ]; then
        log_error "Missing namespace value. Use -n to specify namespace.."
        exit 1
    fi

    if [ -z "${CERT_PATH}" ]; then
        log_error "Missing cert-path. Use -c to specify cert-path if you have one. Otherwise pass -a for auto-cert-generation.."
        exit 1
    fi

    if [ -z "${KEY_PATH}" ]; then
        log_error "Missing key-path. Use -k to specify key-path in a file if you have. Otherwise pass -a for auto-cert-generation.."
        exit 1
    fi


    SECRET_NAME="cml-tls-secret" # CML expects this exact name

    log_info "Creating secrets out of TLS certs"
    run_kubectl_cmd "kubectl create secret tls ${SECRET_NAME} --cert=${CERT_PATH} --key=${KEY_PATH} -o yaml --dry-run | kubectl -n ${K8_NAMESPACE} apply -f -"

}

add_docker_registry_credentials() {

    while getopts "n:h:u:p:" options
    do
        case ${options} in
            (n)
                K8_NAMESPACE=${OPTARG}
                ;;
            (h)
                DOCKER_HOST=${OPTARG}
                ;;
            (u)
                DOCKER_USERNAME=${OPTARG}
                ;;
            (p)
                DOCKER_PASSWORD=${OPTARG}
                ;;
            (?)
                log_error "Invalid option ${OPTARG} passed .. "
                exit 1
                ;;
        esac
    done

    if [ -z "${K8_NAMESPACE}" ]; then
        log_error "Missing namespace value. Use -n to specify namespace.."
        exit 1
    fi

    if [ -z "${DOCKER_HOST}" ]; then
            log_error "Missing Docker Server Host. Use -h to specify namespace.."
            exit 1
    fi

    if [ -z "${DOCKER_USERNAME}" ]; then
            log_error "Missing Docker Username. Use -u to specify namespace.."
            exit 1
    fi

    if [ -z "${DOCKER_PASSWORD}" ]; then
            log_error "Missing Docker Password . Use -p to specify namespace.."
            exit 1
    fi

    log_info "Adding Docker registry credentials"
    run_kubectl_cmd "kubectl create secret docker-registry regcred --docker-server=${DOCKER_HOST} --docker-username=${DOCKER_USERNAME} --docker-password=${DOCKER_PASSWORD} -n ${K8_NAMESPACE}"
}

main() {

    subcommand="$1"
    if [ x"${subcommand}x" == "xx" ]; then
        subcommand="help"
    else
        shift # past sub-command
    fi

    case $subcommand in
        help)
            subcommand_usage
            ;;
        upload-cert)
            ml_cert_installation "$@"
            ;;

        add-docker-registry-credentials)
            add_docker_registry_credentials "$@"
            ;;
        *)
            # unknown option
            subcommand_usage
            exit 1
            ;;
    esac

    exit 0
}

# shellcheck disable=SC2068
main $@
exit 0

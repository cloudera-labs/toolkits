#!/bin/bash
# CLOUDERA SCRIPTS FOR CLOUDERA DATA ENGINEERING PRIVATE CLOUD PLUS DATA SERVICE
#
# (C) 2022 Cloudera, Inc. All rights reserved.
#
# Applicable Open Source License: Apache License 2.0
#
# CLOUDERA PROVIDES THIS CODE TO YOU WITHOUT WARRANTIES OF ANY KIND.
# CLOUDERA DISCLAIMS ANY AND ALL EXPRESS AND IMPLIED WARRANTIES WITH
# RESPECT TO THIS CODE, INCLUDING BUT NOT LIMITED TO IMPLIED WARRANTIES
# OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A
# PARTICULAR PURPOSE. CLOUDERA IS NOT LIABLE TO YOU, AND WILL NOT
# DEFEND, INDEMNIFY, NOR HOLD YOU HARMLESS FOR ANY CLAIMS ARISING FROM
# OR RELATED TO THE CODE. AND WITH RESPECT TO YOUR EXERCISE OF ANY
# RIGHTS GRANTED TO YOU FOR THE CODE, CLOUDERA IS NOT LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, PUNITIVE OR
# CONSEQUENTIAL DAMAGES INCLUDING, BUT NOT LIMITED TO, DAMAGES RELATED
# TO LOST REVENUE, LOST PROFITS, LOSS OF INCOME, LOSS OF BUSINESS
# ADVANTAGE OR UNAVAILABILITY, OR LOSS OR CORRUPTION OF DATA.
#
# -----------------------------------------------------------------------------

#!/bin/bash

set -e # Any subsequent(*) commands which fail will cause the shell script to exit immediately

# Program name
PROG=`basename $0`

# Scratch directory
SCRATCH_SPACE="/tmp/`echo ${PROG}-tmp | sed 's/.sh//'`"

dry_run_cmd() {
    cmd="bash -c \"$1\""
    log_info "${DRY_RUN}Running command: ${cmd}"
    log_info "${DRY_RUN}Exit code = $?"
}

run_cmd() {
    cmd="bash -c \"$1\""
    log_info "Running command: ${cmd}"
    bash -c "${cmd}"
    exit_code=`echo $?`
    log_info "Exit code = $exit_code"
    return $exit_code
}

run_kubectl_cmd() {
    export PATH=/opt/cloudera/parcels/ECS/installer/install/bin/linux/:$PATH;
    export KUBECONFIG=${KUBECONFIG:-"/etc/rancher/rke2/rke2.yaml"}
    APISERVER=$(kubectl config view | grep "server:" | awk '{print $2}')
    # Add the apiserver hostname to no proxy
    export NO_PROXY=$(echo $APISERVER | sed -e 's/[^/]*\/\/\([^@]*@\)\?\([^:/]*\).*/\2/')
    if [ -z "${DRY_RUN}" ]; then
        run_cmd "$@"
    else
        dry_run_cmd "$@"
    fi
}

log_info() {
    echo "INFO : ${1}" 1>&2
}

log_error() {
    error="$1"
    echo "ERROR: ${error}" 1>&2
}

subcommand_usage() {
    echo "Usage: ${0} [-d('dry-run')].
    Sub-commands:
                                help    Prints this message
                init-virtual-cluster    Initialize a CDE Virtual Cluster            -h <virtual-cluster-host> [-a('auto-generate-certs')]
                                                                                    -h <virtual-cluster-host> -c <certificate-path> -k <keyfile-path> [-w('enable wildcard certificate')]
        init-user-in-virtual-cluster    Initialize a user in a CDE Virtual Cluster  -h <virtual-cluster-host> -u <workload-user> -p <principal-file> -k <keytab-file>
        delete-user-in-virtual-cluster  Delete a user in a CDE Virtual Cluster      -h <virtual-cluster-host> -u <workload-user>" 1>&2
}

auto_create_certs() {
    DOMAIN_NAME=$1
    VC_ID=`echo ${DOMAIN_NAME} | cut -d. -f 1`
    if [ ${#DOMAIN_NAME} -lt 64 ]; then
      log_info "Using the domain name as-is:$DOMAIN_NAME";
    else
      DOMAIN_NAME=${DOMAIN_NAME/$VC_ID/\*};
      log_info "Domain name is too long, generating wild card certificate with the domain:$DOMAIN_NAME";
    fi

    CERT_DIR="${SCRATCH_SPACE}/certs"
    run_cmd "mkdir -p ${CERT_DIR}"

    AUTO_GENERATED_KEY_FILE="ssl.key"
    AUTO_GENERATED_CERT_FILE="ssl.crt"

    cat >${CERT_DIR}/req.conf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

prompt = no
[req_distinguished_name]
CN = ${DOMAIN_NAME}
[v3_req]
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${DOMAIN_NAME}
EOF

    # Generate the certificate
    run_cmd "openssl req -new -newkey RSA:2048 -nodes -keyout ${CERT_DIR}/${AUTO_GENERATED_KEY_FILE} -out ${CERT_DIR}/ssl.csr -extensions v3_req -config ${CERT_DIR}/req.conf"

    # Sign the certificate
    run_cmd "openssl x509 -req -days 365 -in ${CERT_DIR}/ssl.csr -signkey ${CERT_DIR}/ssl.key -out ${CERT_DIR}/${AUTO_GENERATED_CERT_FILE} -extensions v3_req -extfile ${CERT_DIR}/req.conf"

    # Cleanup
    run_cmd "rm ${CERT_DIR}/req.conf"
    run_cmd "rm ${CERT_DIR}/ssl.csr"
    export CERT_PATH=${CERT_DIR}/${AUTO_GENERATED_CERT_FILE}
    export KEY_PATH=${CERT_DIR}/${AUTO_GENERATED_KEY_FILE}
}

subcommand_init_base_cluster() {
    OPTS="${@}"

    SCOPE="dex-base"
    __setup_ingress ${SCOPE} ${OPTS}
}

subcommand_init_virtual_cluster() {
    OPTS="${@}"

    SCOPE="dex-base"
    __setup_ingress ${SCOPE} ${OPTS}
    SCOPE="dex-app"
    __setup_ingress ${SCOPE} ${OPTS}
}

__setup_ingress() {
    SCOPE=${1}
    shift # past scope

    unset OPTIND OPTARG options

    while getopts "h:ac:wk:" options
    do
        case ${options} in
            (h)
                INGRESS_HOST=${OPTARG}
                ENTIRE_HOST=`echo ${INGRESS_HOST}`

                BASE_ID=`echo ${INGRESS_HOST} | cut -d. -f 2 | sed 's/cde-//g'`
                VC_ID=`echo ${INGRESS_HOST} | cut -d. -f 1`

                K8S_NAMESPACE="dex-base-${BASE_ID}" # All changes only in base name-space

                if [ "${SCOPE}" == "dex-base" ]; then
                    INGRESS_PREFIX="dex-base"
                    INGRESS_HOST=`echo ${INGRESS_HOST/${VC_ID}/service}`
                elif [ "${SCOPE}" == "dex-app" ]; then
                    INGRESS_PREFIX="${SCOPE}-${VC_ID}"
                fi

                SECRET_NAME="tls-${INGRESS_PREFIX}"
                DOMAIN_NAME=${INGRESS_HOST}
                ;;
            (a)
                AUTO_CREATE_CERTS="yes"
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
            (w)
                WILDCARD_CERTS="yes"
                INGRESS_PREFIX=${ENTIRE_HOST}

                BASE_ID=`echo ${ENTIRE_HOST} | cut -d. -f 1 | cut -d- -f 3`
                VC_ID=`echo ${INGRESS_HOST} | cut -d- -f 1`

                K8S_NAMESPACE="dex-base-${BASE_ID}" # All changes only in base name-space

                if [ "${SCOPE}" == "dex-base" ]; then
                    INGRESS_PREFIX="dex-base"
                    INGRESS_HOST=`echo ${INGRESS_HOST/${VC_ID}/service}`
                elif [ "${SCOPE}" == "dex-app" ]; then
                    INGRESS_PREFIX="${SCOPE}-${VC_ID}"
                fi

                SECRET_NAME="tls-dex-app"
                DOMAIN_NAME=${INGRESS_HOST}
                ;;
            (?)
                log_error "Invalid option ${OPTARG} passed .. "
                exit 1
                ;;
        esac
    done

    if [ -z "${INGRESS_HOST}" ]; then
        log_error "Missing host value. Use -h to specify the host.."
        exit 1
    fi

    if ! [ -z ${AUTO_CREATE_CERTS} ]; then
        if [ -z ${DOMAIN_NAME} ]; then
            log_error "Missing domain-name value. Use -d to specify domain-name if you want to automatically generate certs (-a option).."
            exit 1
        fi
        auto_create_certs ${DOMAIN_NAME}
    else
        if [ -z "${CERT_PATH}" ]; then
            log_error "Missing cert-path. Use -c to specify cert-path if you have one. Otherwise pass -a for auto-cert-generation.."
            exit 1
        elif [ -z "${KEY_PATH}" ]; then
            log_error "Missing key-path. Use -k to specify key-path in a file if you have. Otherwise pass -a for auto-cert-generation.."
            exit 1
        fi
    fi

    log_info "Creating secrets out of TLS certs"
    run_kubectl_cmd "kubectl create secret tls ${SECRET_NAME} --cert=${CERT_PATH} --key=${KEY_PATH} -o yaml --dry-run | kubectl apply -f - -n ${K8S_NAMESPACE}"

    log_info "Checking if ingresses was already fixed before .. "
    rc=`run_kubectl_cmd "kubectl describe ingress ${INGRESS_PREFIX}-api -n ${K8S_NAMESPACE} | grep ${SECRET_NAME} | grep ${INGRESS_HOST} || true"`
    if [ x"${rc}"x != x""x ]; then
         log_info "Ingress ${INGRESS_PREFIX}-api patched already in ${K8S_NAMESPACE} namespace with the updated tls secret"
         return
    fi
    log_info "Ingresses not already fixed, doing so now .. "

    if [ -z ${WILDCARD_CERTS} ] || [ ${WILDCARD_CERTS} != "yes" ]; then
        # Edit the ingress objects to pass along the tls-certificate
        log_info "Injecting TLS certs in the clusters as a secret object"

        SED_CMD="s/^spec:/spec:\n  tls:\n    - hosts:\n      - ${INGRESS_HOST}\n      secretName: ${SECRET_NAME}/g"
        export KUBE_EDITOR="sed -i \"${SED_CMD}\""
        log_info "${KUBE_EDITOR}"

        run_kubectl_cmd "kubectl edit ingress ${INGRESS_PREFIX}-api -n ${K8S_NAMESPACE}"
    else
        log_info "Not editing ingress because of wildcard certificate feature"
    fi

}

subcommand_init_user_in_virtual_cluster() {
    while getopts "h:u:p:k:" options
    do
        case ${options} in
            (h)
                VIRTUAL_CLUSTER_HOST=${OPTARG}
                K8_NAMESPACE="dex-app-`echo ${VIRTUAL_CLUSTER_HOST} | cut -d. -f 1`"
                ;;
            (u) WORKLOAD_USER=${OPTARG} ;;
            (p)
                PRINCIPAL_FILE=${OPTARG}
                # Verify that the principal file actually exists
                if ! [ -f $PRINCIPAL_FILE ]; then
                    log_error "No principal file found at location: ${PRINCIPAL_FILE}.."
                    exit 1
                fi
                ;;
            (k)
                KEYTAB_FILE=${OPTARG}
                # Verify that the keytab files actually exists
                if ! [ -f ${KEYTAB_FILE} ]; then
                    log_error "No keytab file found at location: ${KEYTAB_FILE}.."
                    exit 1
                fi
                ;;
            (?)
                log_error "Invalid option ${OPTARG} passed .. "
                exit 1
                ;;
        esac
    done

    if [ -z "${VIRTUAL_CLUSTER_HOST}" ]; then
        log_error "Missing -host value. Use -h to specify the host.."
        exit 1
    elif [ -z "${WORKLOAD_USER}" ]; then
        log_error "Missing workload-username. Use -u to specify workload-username.."
        exit 1
    elif [ -z "${PRINCIPAL_FILE}" ]; then
        log_error "Missing kerberos-principal. Use -p to specify kerberos-principal in a file.."
        exit 1
    elif [ -z "${KEYTAB_FILE}" ]; then
        log_error "Missing kerberos-keytab file. Use -k to specify kerberos-keytab in a file.."
        exit 1
    fi

    # Encode the WORKLOAD_USER to remove underscores and replace it with triple hyphens
    WORKLOAD_USER="${WORKLOAD_USER//_/---}"

    SECRET_ENCODING_PRINCIPAL=${WORKLOAD_USER}-krb5-principal
    SECRET_ENCODING_KEYTAB=${WORKLOAD_USER}-krb5-secret

    ## TODO: Delete fails on the first try
    log_info "Deleting old secrets in $K8_NAMESPACE.." 2>&1
    run_kubectl_cmd "kubectl delete --ignore-not-found=true secret ${SECRET_ENCODING_KEYTAB}    -n ${K8_NAMESPACE}"
    run_kubectl_cmd "kubectl delete --ignore-not-found=true secret ${SECRET_ENCODING_PRINCIPAL} -n ${K8_NAMESPACE}"

    log_info "Temporarily copying files to desired names.."
    run_cmd "cp ${KEYTAB_FILE}    ${SECRET_ENCODING_KEYTAB}"
    run_cmd "cp ${PRINCIPAL_FILE} ${SECRET_ENCODING_PRINCIPAL}"

    log_info "Creating new secrets in ${K8_NAMESPACE}.."
    run_kubectl_cmd "kubectl create secret generic ${SECRET_ENCODING_PRINCIPAL} --from-file=./${SECRET_ENCODING_PRINCIPAL} -n ${K8_NAMESPACE}"
    run_kubectl_cmd "kubectl create secret generic ${SECRET_ENCODING_KEYTAB}    --from-file=./${SECRET_ENCODING_KEYTAB}     -n ${K8_NAMESPACE}"

    log_info "Deleting temporary files.."
    run_cmd "rm ${SECRET_ENCODING_KEYTAB} ${SECRET_ENCODING_PRINCIPAL}"
}

subcommand_delete_user_in_virtual_cluster() {
    while getopts "h:u:p:k:" options
    do
        case ${options} in
            (h)
                VIRTUAL_CLUSTER_HOST=${OPTARG}
                K8_NAMESPACE="dex-app-`echo ${VIRTUAL_CLUSTER_HOST} | cut -d. -f 1`"
                ;;
            (u) WORKLOAD_USER=${OPTARG} ;;
            (?)
                log_error "Invalid option ${OPTARG} passed .. "
                exit 1
                ;;
        esac
    done

    if [ -z "${VIRTUAL_CLUSTER_HOST}" ]; then
        log_error "Missing -host value. Use -h to specify the host.."
        exit 1
    elif [ -z "${WORKLOAD_USER}" ]; then
        log_error "Missing workload-username. Use -u to specify workload-username.."
        exit 1
    fi

    # Encode the WORKLOAD_USER to remove underscores and replace it with triple hyphens
    WORKLOAD_USER="${WORKLOAD_USER//_/---}"

    SECRET_ENCODING_PRINCIPAL=${WORKLOAD_USER}-krb5-principal
    SECRET_ENCODING_KEYTAB=${WORKLOAD_USER}-krb5-secret

    log_info "Deleting old secrets in $K8_NAMESPACE.." 2>&1
    run_kubectl_cmd "kubectl delete secret ${SECRET_ENCODING_KEYTAB}    -n ${K8_NAMESPACE}"
    run_kubectl_cmd "kubectl delete secret ${SECRET_ENCODING_PRINCIPAL} -n ${K8_NAMESPACE}"
}

main() {

    option=$1
    if [ x"${option}"x == "x-dx" ]; then
        DRY_RUN="(Dry Run: yes) "
        shift
    fi

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
        init-virtual-cluster)
            subcommand_init_virtual_cluster "$@"
            ;;
        init-base-cluster)
            subcommand_init_base_cluster "$@"
            ;;
        init-user-in-virtual-cluster)
            subcommand_init_user_in_virtual_cluster "$@"
            ;;
        delete-user-in-virtual-cluster)
            subcommand_delete_user_in_virtual_cluster "$@"
            ;;
        *)
            # unknown option
            subcommand_usage
            exit 1
            ;;
    esac

    exit 0
}

main "$@"
exit 0

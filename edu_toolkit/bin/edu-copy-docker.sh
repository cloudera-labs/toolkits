#!/bin/bash

# (c) Copyright 2020 Cloudera, Inc. All rights reserved.
# This script copies Docker images for CDP Private Cloud from Cloudera into your
# custom Docker Registry server under the path that you specify.
#
# Prerequisites:
# --------------
# You must run this script from a machine that either has a Docker daemon
# or Podman running, and has fast network access to the Docker Registry server.
# This could be a remote terminal or your laptop.
# You must first authenticate against your custom Docker Registry server using a credential
# that has write access to the registry location.
# $> docker login <your-docker-registry-server/some-path>
# or
# $> podman login <your-docker-registry-server/some-path>
# IMPORTANT: Modified by EDU are marked with EDU

# Basic Usage:
# ------------
# The default Docker destination is the value specified in the variable $DOCKER_REGISTRY_DEST below.
# This script is typically created as a .txt file (for security reasons) by the CDP Private Cloud
# installation wizard.
# $> bash <name-of-this-script>
#

# Performance Tip:
# ----------------
# To speed up the copying process, you can run this script multiple times in parallel on the same machine.
# It uses a common local directory to keep track of which images have been fetched by other scripts for
# the same destination. Once all the images have been fetched and uploaded successfully, this local directory
# will be removed automatically.

# Advanced Usage:
# -----------------------
# If you want to have more than one environment inside the CDP Private Cloud, such as in
# a geographically distributed setting (for example, the US and UK), you can setup a second
# docker registry server to improve performance.
#
# You can use this script to copy all the Docker images to this second registry by running this command:
# $> bash <name-of-this-script> <second-docker-registry-server/repository_name>

# EDU points to classroom host registry-1
# The next line sets the following variable to the first command line argument if present.
DOCKER_REGISTRY_DEST=${1:-registry-1.example.com:5000/cloudera-docker-images}
# The next line sets the following variable to the second command line argument if present.
COPY_DOCKER_MODE=${2:-DOWNLOAD_OR_PULL_AND_PUSH}

# Tip:
# ----
# To speed up the copying process, you can also run this script multiple times in parallel on the same machine.
# It uses a common local directory to keep track which images have been fetched by other scripts for
# the same destination. Once all the images have been fetched and uploaded successfully, this local directory
# will be removed automatically.

echo "This script pushes all Docker images used in CDP Private Cloud to the specified custom Docker Repository."
echo "Start download Docker images to $DOCKER_REGISTRY_DEST."
completedCount=0
errorCount=0

# replace ':' with '-' for compatibility with certain podman versions
# certain versions can't do a podman load on a filename containing a ':'
TOP_LEVEL_DIR="/tmp/cloudera/cdp-private/${DOCKER_REGISTRY_DEST//[:]/-}/1.5.0-b448"
mkdir -p $TOP_LEVEL_DIR

# determines whether to use Podman or Docker, Docker takes precedence
# the inspect format depends on whether Podman or Docker is used
PODMAN_OR_DOCKER="docker"
INSPECT_ID_FMT="{{index .Id}}"
command -v docker
if [ $? -ne 0 ]; then
  PODMAN_OR_DOCKER="podman"
  INSPECT_ID_FMT="sha256:{{.Id}}"
fi
echo "Using $PODMAN_OR_DOCKER to process the images."

# check if stdout is a terminal...
if test -t 1; then

    # see if it supports colors...
    ncolors=$(tput colors)

    if test -n "$ncolors" && test $ncolors -ge 8; then
        bold="$(tput bold)"
        normal="$(tput sgr0)"
        error="$(tput setaf 1)"
        warning="$(tput setaf 3)"
    fi
fi

onExit() {
  echo ''
  if [ "$COPY_DOCKER_MODE" = "DOWNLOAD_OR_PULL_AND_PUSH" ] || [ "$COPY_DOCKER_MODE" = "DOCKER_PUSH_ONLY" ]; then
    # The total number includes the number of all the independent docker images and
    # the number of all the docker images inside packages.
    # $completedCount should only be incremented after docker push operations.
    echo "Downloaded and pushed $completedCount/270 Docker images to $DOCKER_REGISTRY_DEST."
  fi

  if [ $completedCount -eq 270 ]; then
# EDU Remove this line to preserve the Docker packages in the temp location
#    rm -rf "$TOP_LEVEL_DIR"
    exit 0
  elif [ $errorCount -eq 0 ]; then
    echo "Remaining images are being processed by another script."
    exit 0
  elif [ "$COPY_DOCKER_MODE" = "DOWNLOAD_OR_PULL_AND_PUSH" ]; then
    echo "${error}Failed to download and push $errorCount images.${normal}"
    echo "${warning}Try running the script again. It will skip any images that have been processed successfully.${normal}"
    exit 1
  elif [ "$COPY_DOCKER_MODE" = "DOWNLOAD_OR_PULL_ONLY" ]; then
    echo "${error}Failed to download or pull $errorCount images.${normal}"
    echo "${warning}Try running the script again. It will skip any images that have been downloaded or pulled successfully.${normal}"
    exit 1
  elif [ "$COPY_DOCKER_MODE" = "DOCKER_PUSH_ONLY" ]; then
    echo "${error}Failed to $PODMAN_OR_DOCKER push $errorCount images.${normal}"
    echo "${warning}Try running the script again. It will skip any images that have been pushed successfully.${normal}"
    exit 1
  fi
}

onInterrupt() {
  if [ "$COPY_DOCKER_MODE" = "DOWNLOAD_OR_PULL_AND_PUSH" ]; then
    rm -f "$CURRENT_PROGRESS_MARKER"
  fi
  exit
}

trap onInterrupt SIGINT
trap onExit EXIT

# The status for each CURRENT_PROGRESS_MARKER file can contain one of the following
# started
# downloaded
# download failed
# pushing
# done

# Used when the script runs on its own and the manifest.json contains container images as tarballs.
# Used by release candidates or production builds.
downloadAndPush() {
  index=$1
  imageLocationPathAndTag=$2
  imagePathTag=$3
  imageSha=$4
  imageSize=$5
  imageTgz=$6
  imageFileName=$(basename "$imageTgz")
  imagePathTagAsFileName=$(echo "$imagePathTag"|tr / -)
  echo ''
  echo "${bold}Processing $index/270 $imagePathTag${normal}"

  export CURRENT_PROGRESS_MARKER="$TOP_LEVEL_DIR/$imagePathTagAsFileName"
  if [ ! -f "$CURRENT_PROGRESS_MARKER" ]; then
    echo 'started' > "$CURRENT_PROGRESS_MARKER"
    curl --insecure --retry 10 -C - -o "$TOP_LEVEL_DIR/$imageFileName" "http://cmhost:8060/cdp-pvc-ds/1.5.0/$imageTgz"
    if [ $? -ne 0 ]; then
      ((errorCount+=1))
      # This method is invoked manually by the user.
      # When pull failed, we need to make sure this file is not present so user can retry.
      rm -f "$CURRENT_PROGRESS_MARKER"
      echo "${error}Failed to download http://cmhost:8060/cdp-pvc-ds/1.5.0/$imageTgz${normal}"
    else
      echo 'downloaded' > "$CURRENT_PROGRESS_MARKER"
      imageRegistryAndPathTag=$($PODMAN_OR_DOCKER load -i "$TOP_LEVEL_DIR/$imageFileName"|sed -e 's/^[^:]*: //')
      actualImageSha=$($PODMAN_OR_DOCKER inspect --format="$INSPECT_ID_FMT" "$imageRegistryAndPathTag")
      if [ "$imageSha" = "$actualImageSha" ]; then
        $PODMAN_OR_DOCKER tag "$imageRegistryAndPathTag" "$DOCKER_REGISTRY_DEST/$imagePathTag"
        $PODMAN_OR_DOCKER push "$DOCKER_REGISTRY_DEST/$imagePathTag"
        dockerPushStatus=$(echo $?)

        if [ $dockerPushStatus -eq 0 ]; then
          ((completedCount+=1))
          echo 'done' > "$CURRENT_PROGRESS_MARKER"
        else
          ((errorCount+=1))
          rm -f "$CURRENT_PROGRESS_MARKER"
          echo "${error}Failed to perform $PODMAN_OR_DOCKER push $DOCKER_REGISTRY_DEST/$imagePathTag${normal}"
        fi
        $PODMAN_OR_DOCKER image rm "$DOCKER_REGISTRY_DEST/$imagePathTag"
      else
        ((errorCount+=1))
        rm -f "$CURRENT_PROGRESS_MARKER"
        echo "$imageSha is different from $actualImageSha"
        echo "${error}Image checksum for $imageRegistryAndPathTag does not match.${normal}"
      fi
      $PODMAN_OR_DOCKER image rm "$imageRegistryAndPathTag"
      rm -f "$TOP_LEVEL_DIR/$imageFileName"
    fi
  else
    status=$(cat "$CURRENT_PROGRESS_MARKER")
    if [ "$status" = "done" ]; then
      ((completedCount+=1))
      echo 'Already downloaded.'
    else
      echo 'Downloading in another script, skipping.'
    fi
  fi
}

# Used when the script runs on its own and the manifest.json DOES not contain container images as tarballs.
# Used by dev builds.
dockerPullAndPush() {
  index=$1
  imageLocationPathAndTag=$2
  imagePathTag=$3
  imageSha=$4
  imageSize=$5
  imagePathTagAsFileName=$(echo "$imagePathTag"|tr / -)
  echo ''
  echo "${bold}Processing $index/270 $imagePathTag${normal}"

  export CURRENT_PROGRESS_MARKER="$TOP_LEVEL_DIR/$imagePathTagAsFileName"
  if [ ! -f "$CURRENT_PROGRESS_MARKER" ]; then
    echo 'started' > "$CURRENT_PROGRESS_MARKER"
    $PODMAN_OR_DOCKER pull "$imageLocationPathAndTag"
    if [ $? -ne 0 ]; then
      echo "${error}Failed to $PODMAN_OR_DOCKER pull $imageLocationPathAndTag${normal}"
      ((errorCount+=1))
      # This method is invoked manually by the user.
      # When pull failed, we need to make sure this file is not present so user can retry.
      rm -f "$CURRENT_PROGRESS_MARKER"
    else
      echo 'downloaded' > "$CURRENT_PROGRESS_MARKER"
      actualImageSha=$($PODMAN_OR_DOCKER inspect --format="$INSPECT_ID_FMT" "$imageLocationPathAndTag")
      # TODO: OPSX-789 Remove || "$imageSha" != "$actualImageSha" once the image sha matches.
      if [[ "$imageSha" = "$actualImageSha" || -z "$imageSha" || "$imageSha" != "$actualImageSha" ]]; then
        $PODMAN_OR_DOCKER tag "$imageLocationPathAndTag" "$DOCKER_REGISTRY_DEST/$imagePathTag"
        $PODMAN_OR_DOCKER push "$DOCKER_REGISTRY_DEST/$imagePathTag"
        dockerPushStatus=$(echo $?)
        if [ $dockerPushStatus -eq 0 ]; then
          ((completedCount+=1))
          echo 'done' > "$CURRENT_PROGRESS_MARKER"
          echo "Pushed  $index/270 $imagePathTag"
        else
          ((errorCount+=1))
          rm -f "$CURRENT_PROGRESS_MARKER"
          echo "${error}Failed to perform $PODMAN_OR_DOCKER push $DOCKER_REGISTRY_DEST/$imagePathTag${normal}"
        fi
        $PODMAN_OR_DOCKER image rm "$DOCKER_REGISTRY_DEST/$imagePathTag"
      else
        ((errorCount+=1))
        rm -f "$CURRENT_PROGRESS_MARKER"
        echo "$imageSha is different from $actualImageSha"
        echo "${error}Image checksum for $imageLocationPathAndTag does not match.${normal}"
      fi
      $PODMAN_OR_DOCKER image rm "$imageLocationPathAndTag"
    fi
  else
    status=$(cat "$CURRENT_PROGRESS_MARKER")
    if [ "$status" = "done" ]; then
      ((completedCount+=1))
      echo 'Already downloaded.'
    else
      echo 'Downloading in another script, skipping.'
    fi
  fi
}

# Some docker images are put together in a single package.
# The status of a package can be
# 'started', 'downloaded', 'download failed', 'load failed', or 'done'.
downloadPackageOnly() {
  imageSha=$1
  imageSize=$2
  imageTgz=$3
  imageFileName=$(basename "$imageTgz")

  export CURRENT_PROGRESS_MARKER="$TOP_LEVEL_DIR/$imageFileName-status"
  status=""
  if [ -f "$CURRENT_PROGRESS_MARKER" ]; then
    status=$(cat "$CURRENT_PROGRESS_MARKER")
  fi

  # The status of a packge is different from a docker image.
  # So when it is not in a good state, we can move it to 'started'
# EDU Pull from the air-gap repo on cmhost
  if [ "$status" != "started" ] && [ "$status" != "downloaded" ] && [ "$status" != "done" ]; then
    echo ''
    echo "${bold}Downloading $imageTgz${normal}"
    echo 'started' > "$CURRENT_PROGRESS_MARKER"
    curl --insecure --retry 10 -C - -o "$TOP_LEVEL_DIR/$imageFileName" "http://cmhost:8060/cdp-pvc-ds/1.5.0/$imageTgz"
    if [ $? -ne 0 ]; then
      ((errorCount+=1))
      # This method does only the download portion, so it needs to let
      # the corresponding push method know that the download failed.
      echo "download failed" > "$CURRENT_PROGRESS_MARKER"
      echo "${error}Failed to download http://cmhost:8060/cdp-pvc-ds/1.5.0/$imageTgz${normal}"
    else
      $PODMAN_OR_DOCKER load -i "$TOP_LEVEL_DIR/$imageFileName"
      if [ $? -ne 0 ]; then
        echo "load failed" > "$CURRENT_PROGRESS_MARKER"
        echo "${error}Failed to load $imageFileName"
        ((errorCount+=1))
      else
        echo "downloaded" > "$CURRENT_PROGRESS_MARKER"
      fi
    fi
  fi
}

# During production mode, some images are downloaded as part of a package.
# We need to mark those images as downloaded to unblock the docker push procedure.
markAsDownloaded() {
  imagePathTag=$1
  imageTgz=$2
  imageFileName=$(basename "$imageTgz")

  export CURRENT_PACKAGE_PROGRESS_MARKER="$TOP_LEVEL_DIR/$imageFileName-status"
  package_status=""
  if [ -f "$CURRENT_PACKAGE_PROGRESS_MARKER" ]; then
    package_status=$(cat "$CURRENT_PACKAGE_PROGRESS_MARKER")
  fi

  imagePathTagAsFileName=$(echo "$imagePathTag"|tr / -)
  export CURRENT_PROGRESS_MARKER="$TOP_LEVEL_DIR/$imagePathTagAsFileName"

  package_status=$(cat "$CURRENT_PACKAGE_PROGRESS_MARKER")
  if [ "$package_status" = "downloaded" ]; then
    status=""
    if [ -f "$CURRENT_PROGRESS_MARKER" ]; then
      status=$(cat "$CURRENT_PROGRESS_MARKER")
    fi

    # The status of an image inside a package could be either
    # nothing, 'downloaded', 'pushing', or 'done'.
    # When it is none of the above, put it in the initial state 'downloaded'.
    if [ "$status" != "downloaded" ] && [ "$status" != "pushing" ] && [ "$status" != "done" ]; then
      echo "downloaded" > "$CURRENT_PROGRESS_MARKER"
    fi
  fi
}

# Downloads the image and tag it locally.
# Used when the scripts run in pairs. One does the download and one does the push.
# Used by release candidates or production builds.
downloadOnly() {
  index=$1
  imageLocationPathAndTag=$2
  imagePathTag=$3
  imageSha=$4
  imageSize=$5
  imageTgz=$6
  imageFileName=$(basename "$imageTgz")
  imagePathTagAsFileName=$(echo "$imagePathTag"|tr / -)

  export CURRENT_PROGRESS_MARKER="$TOP_LEVEL_DIR/$imagePathTagAsFileName"
  status=""
  if [ -f "$CURRENT_PROGRESS_MARKER" ]; then
    status=$(cat "$CURRENT_PROGRESS_MARKER")
  fi

  # There could be multiple scripts processing an image.
  # So we must not try to do anything if it is already getting processed by another script.
  if [ "$status" != "downloaded" ] && [ "$status" != "pushing" ] && [ "$status" != "done" ]; then
    echo ''
    echo "${bold}Downloading $index/270 $imageTgz for $imagePathTag${normal}"
    echo 'started' > "$CURRENT_PROGRESS_MARKER"
    curl --insecure --retry 10 -C - -o "$TOP_LEVEL_DIR/$imageFileName" "http://cmhost:8060/cdp-pvc-ds/1.5.0/$imageTgz"
    if [ $? -ne 0 ]; then
      ((errorCount+=1))
      # This method does only the download portion, so it needs to let
      # the corresponding push method know that the download failed.
      echo "download failed" > "$CURRENT_PROGRESS_MARKER"
      echo "${error}Failed to download http://cmhost:8060/cdp-pvc-ds/1.5.0/$imageTgz${normal}"
    else
      imageRegistryAndPathTag=$($PODMAN_OR_DOCKER load -i "$TOP_LEVEL_DIR/$imageFileName"|sed -e 's/^[^:]*: //')
      actualImageSha=$($PODMAN_OR_DOCKER inspect --format="$INSPECT_ID_FMT" "$imageRegistryAndPathTag")
      if [ "$imageSha" = "$actualImageSha" ]; then
        $PODMAN_OR_DOCKER tag "$imageRegistryAndPathTag" "$DOCKER_REGISTRY_DEST/$imagePathTag"
        echo "downloaded" > "$CURRENT_PROGRESS_MARKER"
        echo "Downloaded  $index/270 $imageTgz"
      elif [ "$actualImageSha" = "" ]; then
        ((errorCount+=1))
        # This method does only the download portion, so it needs to let
        # the corresponding push method know that the download failed, or more specifically, the load failed.
        # However, we don't treat load failed differently, so using the same marker for both cases.
        echo "download failed" > "$CURRENT_PROGRESS_MARKER"
        echo "Could not retrieve the image information. The file $imageTgz might be invalid or inaccessible."
      else
        ((errorCount+=1))
        echo "download failed" > "$CURRENT_PROGRESS_MARKER"
        echo "$imageSha is different from $actualImageSha"
        echo "${error}Image checksum for $imageRegistryAndPathTag does not match.${normal}"
      fi
      $PODMAN_OR_DOCKER image rm "$imageRegistryAndPathTag"
    fi
  fi
}

# Pulls down the image and tag it locally.
# Used when the scripts run in pairs. One does the pull and one does the push.
# Used by dev builds.
dockerPullOnly() {
  index=$1
  imageLocationPathAndTag=$2
  imagePathTag=$3
  imageSha=$4
  imageSize=$5
  imagePathTagAsFileName=$(echo "$imagePathTag"|tr / -)

  export CURRENT_PROGRESS_MARKER="$TOP_LEVEL_DIR/$imagePathTagAsFileName"
  status=""
  if [ -f "$CURRENT_PROGRESS_MARKER" ]; then
    status=$(cat "$CURRENT_PROGRESS_MARKER")
  fi

  # There could be multiple scripts processing an image.
  # So we must not try to do anything if it is already getting processed by another script.
  if [ "$status" != "downloaded" ] && [ "$status" != "pushing" ] && [ "$status" != "done" ]; then
    echo ''
    echo "${bold}Pulling $index/270 $imagePathTag${normal}"
    echo 'started' > "$CURRENT_PROGRESS_MARKER"
    $PODMAN_OR_DOCKER pull "$imageLocationPathAndTag"
    if [ $? -ne 0 ]; then
      ((errorCount+=1))
      echo "download failed" > "$CURRENT_PROGRESS_MARKER"
      echo "${error}Failed to $PODMAN_OR_DOCKER pull $imageLocationPathAndTag${normal}"
    else
      $PODMAN_OR_DOCKER tag "$imageLocationPathAndTag" "$DOCKER_REGISTRY_DEST/$imagePathTag"
      echo "Pulled  $index/270 $imageLocationPathAndTag"
      echo "downloaded" > "$CURRENT_PROGRESS_MARKER"
    fi
    $PODMAN_OR_DOCKER image rm "$imageLocationPathAndTag"
  fi
}

# Used when the scripts run in pairs. One does the download/pull and one does the push.
# Used by either release candidates, production builds, or dev builds.
dockerPushOnly() {
  index=$1
  imageLocationPathAndTag=$2
  imagePathTag=$3
  imageSha=$4
  imageSize=$5
  performTag=$6
  imagePathTagAsFileName=$(echo "$imagePathTag"|tr / -)

  export CURRENT_PROGRESS_MARKER="$TOP_LEVEL_DIR/$imagePathTagAsFileName"
  status=""
  if [ -f "$CURRENT_PROGRESS_MARKER" ]; then
    status=$(cat "$CURRENT_PROGRESS_MARKER")
  fi

  echo ''
  echo "${bold}Processing $index/270 $imagePathTag${normal}"

  # max time out is 30 minutes
  timeout=1800
  timeElapsed=0

  # Waiting for the status to become one of the known states, so we can continue.
  until [ "$status" = "downloaded" ] || [ "$status" = "pushing" ] || [ "$status" = "download failed" ] || [ "$status" = "done" ]
  do
    if [ $timeElapsed -gt $timeout ]; then
      break
    fi
    sleep 10
    echo -n '.'
    status=$(cat "$CURRENT_PROGRESS_MARKER")
    timeElapsed=$(($timeElapsed+10))
  done
  echo ''

  if [ "$status" = "downloaded" ]; then
    # which ever script reaches here will need to change
    # the marker to something other than 'downloaded' to prevent
    # multiple push operations.
    echo "pushing" > "$CURRENT_PROGRESS_MARKER"
    echo "Pushing ..."

    if [ "$performTag" == "true" ]; then
      $PODMAN_OR_DOCKER tag "$imageLocationPathAndTag" "$DOCKER_REGISTRY_DEST/$imagePathTag"
    fi

    $PODMAN_OR_DOCKER push "$DOCKER_REGISTRY_DEST/$imagePathTag"
    dockerPushStatus=$(echo $?)
    if [ $dockerPushStatus -eq 0 ]; then
      ((completedCount+=1))
      echo "Pushed  $index/270 $imagePathTag"
      echo 'done' > "$CURRENT_PROGRESS_MARKER"
      $PODMAN_OR_DOCKER image rm "$DOCKER_REGISTRY_DEST/$imagePathTag"

      if [ "$performTag" == "true" ]; then
        $PODMAN_OR_DOCKER image rm "$imageLocationPathAndTag"
      fi
    else
      ((errorCount+=1))
      # Move the status back to downloaded sice push failed.
      echo 'downloaded' > "$CURRENT_PROGRESS_MARKER"
      echo "docker push exit code = $dockerPushStatus"
      echo "${error}Failed to perform $PODMAN_OR_DOCKER push $DOCKER_REGISTRY_DEST/$imagePathTag${normal}"
    fi
  elif [ "$status" = "done" ]; then
    # If the push script had to run for the second time, we still want to track all the done items.
    ((completedCount+=1))
    echo 'The image was already processed.'
  elif [ "$status" = "pushing" ]; then
    echo 'Pushing in another script, skipping.'
  else
    ((errorCount+=1))
    echo "${error}The image was not downloaded or pulled successfully.${normal}"
  fi
}

downloadAndPush 1 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/longhornio/backing-image-manager:v3_20221003 cloudera_thirdparty/longhornio/backing-image-manager:v3_20221003 sha256:1a7095f7e9bc923c59f2250f9fb5b0d3ac6ff0a550104789b4a63768b1c2e9ee 316Mi images/backing-image-manager-v3_20221003.tar.gz false
downloadAndPush 2 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/busybox-rootless:1.32 cloudera_thirdparty/busybox-rootless:1.32 sha256:3998450882fccfa2756fb73d1229e99a1e6e77c8e8912cc252b0844f3565eeab 1Mi images/busybox-rootless-1.32.tar.gz false
downloadAndPush 3 container.repository.cloudera.com/cdp-private/cloudera/catalogd:2022.0.11.1-15 cloudera/catalogd:2022.0.11.1-15 sha256:426fc8068453b7b9870d40967f6bec3fd33364df0d91662a42e4d773fb8f7a89 908Mi images/catalogd-2022.0.11.1-15.tar.gz false
downloadAndPush 4 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/rhel8/postgresql-10:1-123 cloudera_thirdparty/rhel8/postgresql-10:1-123 sha256:714511ec84b663cfefe45cb1ee0d50dc11ddb173491b6ff942453d33f7085e82 413Mi images/postgresql-10-1-123.tar.gz false
downloadAndPush 5 container.repository.cloudera.com/cdp-private/cloudera/cdpcli:1.5.0-b767 cloudera/cdpcli:1.5.0-b767 sha256:96cc08afef303019cc45bd39210d452268adf6a3acfd0ad1c2c777bab52b30fd 835Mi images/cdpcli-1.5.0-b767.tar.gz false
downloadAndPush 6 container.repository.cloudera.com/cdp-private/cloudera_base/ubi8/ubi-minimal:8.2-301 cloudera_base/ubi8/ubi-minimal:8.2-301 sha256:a5d8ad363d872c665590d3f232d0a4249bfa2c39bd3a141e8d8eb1896a56be78 135Mi images/ubi-minimal-8.2-301.tar.gz false
downloadAndPush 7 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/ubi-pod-reloader:v0.0.69-b8.3-291 cloudera_thirdparty/ubi-pod-reloader:v0.0.69-b8.3-291 sha256:c93249d566e9fac78864c516029111f2e9682d951b59e08e48e0ed1943e4c77c 126Mi images/ubi-pod-reloader-v0.0.69-b8.3-291.tar.gz false
downloadAndPush 8 container.repository.cloudera.com/cdp-private/cloudera/cdsw/api:2.0.35-b101 cloudera/cdsw/api:2.0.35-b101 sha256:b601c605c4f2ec7fc34b38be0640033db2851106e1eef16237c9fbdbece33317 73Mi images/api-2.0.35-b101.tar.gz false
downloadAndPush 9 container.repository.cloudera.com/cdp-private/cloudera/cdsw/cdh-client:2.0.35-b101 cloudera/cdsw/cdh-client:2.0.35-b101 sha256:1c4def865fc05cca62829693d83396332f1e9771254a3b7de0ec703344a46b34 30Mi images/cdh-client-2.0.35-b101.tar.gz false
downloadAndPush 10 container.repository.cloudera.com/cdp-private/cloudera/cdsw/cdsw-ubi-minimal:2.0.35-b101 cloudera/cdsw/cdsw-ubi-minimal:2.0.35-b101 sha256:30cb4d1a542ceb6e0f01f93e64980dcc5f2fb64da72607fcd493adbf8c057ad4 101Mi images/cdsw-ubi-minimal-2.0.35-b101.tar.gz false
downloadAndPush 11 container.repository.cloudera.com/cdp-private/cloudera/cdsw/cron:2.0.35-b101 cloudera/cdsw/cron:2.0.35-b101 sha256:16e6139ac2dc36f37d2ffa2aa50c96e7f8d4629c096a967b0084c830672f0a89 7Mi images/cron-2.0.35-b101.tar.gz false
downloadAndPush 12 container.repository.cloudera.com/cdp-private/cloudera/cdsw/engine-deps:2.0.35-b101 cloudera/cdsw/engine-deps:2.0.35-b101 sha256:c97827a32ca537212edf33cb3aff0a059647cc17265a95eac5de5b7935b54450 94Mi images/engine-deps-2.0.35-b101.tar.gz false
downloadAndPush 13 container.repository.cloudera.com/cdp-private/cloudera/cdsw/eventlog-reader:2.0.35-b101 cloudera/cdsw/eventlog-reader:2.0.35-b101 sha256:95374cae32bb0b77bbded50679edb7e05e9883d8c7ce66ec8c173089726b154f 281Mi images/eventlog-reader-2.0.35-b101.tar.gz false
downloadAndPush 14 container.repository.cloudera.com/cdp-private/cloudera/cdsw/feature-flags:2.0.35-b101 cloudera/cdsw/feature-flags:2.0.35-b101 sha256:eefa239dade6b33ab8965e109558908432b1bb0c16385d699f1edf8fcb92ef04 905Mi images/feature-flags-2.0.35-b101.tar.gz false
downloadAndPush 15 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/fluent-bit:v1.7.1 cloudera_thirdparty/fluent-bit:v1.7.1 sha256:00b8789c40c7c9e1615c711728636085c63485d21d6751382cc4fd9315026362 212Mi images/fluent-bit-v1.7.1.tar.gz false
downloadAndPush 16 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/fluentd:v1.10.2-cldr-3 cloudera_thirdparty/fluentd:v1.10.2-cldr-3 sha256:dc5b6c8d011d9f7ef065c7c5b119167e86c30d8d6dedb611bfba0cc9ae0244e3 297Mi images/fluentd-v1.10.2-cldr-3.tar.gz false
downloadAndPush 17 container.repository.cloudera.com/cdp-private/cloudera/cdsw/kinit:2.0.35-b101 cloudera/cdsw/kinit:2.0.35-b101 sha256:87e87010a337919ed93d5335d660c6de1dcc7cbd1f92ea80c98a636a19287360 6Mi images/kinit-2.0.35-b101.tar.gz false
downloadAndPush 18 container.repository.cloudera.com/cdp-private/cloudera/cdsw/livelog:2.0.35-b101 cloudera/cdsw/livelog:2.0.35-b101 sha256:2199ab8f378a5be77b38932f0c7327c12a00ed0d6a35218d5487d35fa309fad6 443Mi images/livelog-2.0.35-b101.tar.gz false
downloadAndPush 19 container.repository.cloudera.com/cdp-private/cloudera/cdsw/livelog-cleaner:2.0.35-b101 cloudera/cdsw/livelog-cleaner:2.0.35-b101 sha256:5e76c5a1d6caf06704262acc9dea9e5de7f43f4af4d12bf7a1a23eae659ae79d 9Mi images/livelog-cleaner-2.0.35-b101.tar.gz false
downloadAndPush 20 container.repository.cloudera.com/cdp-private/cloudera/cdsw/livelog-publisher:2.0.35-b101 cloudera/cdsw/livelog-publisher:2.0.35-b101 sha256:b7d16fcabe4985a92d52b0a1eadbf4aeb297d35b4de463c6ecedf3b5fd5b109c 32Mi images/livelog-publisher-2.0.35-b101.tar.gz false
downloadAndPush 21 container.repository.cloudera.com/cdp-private/cloudera/cdsw/model-metrics:2.0.35-b101 cloudera/cdsw/model-metrics:2.0.35-b101 sha256:86907e39b1b1663539adac34ba4a6f9a3ae0257c670ce573e3306f184fb4aa20 19Mi images/model-metrics-2.0.35-b101.tar.gz false
downloadAndPush 22 container.repository.cloudera.com/cdp-private/cloudera/cdsw/modelproxy:2.0.35-b101 cloudera/cdsw/modelproxy:2.0.35-b101 sha256:5c31b3c8da7865c8bbd6fc401f06afd5deff3370a6fb61ddd3dbd123978b159a 14Mi images/modelproxy-2.0.35-b101.tar.gz false
downloadAndPush 23 container.repository.cloudera.com/cdp-private/cloudera/cdsw/operator:2.0.35-b101 cloudera/cdsw/operator:2.0.35-b101 sha256:b232074f93d01d6beeb11b616345acceeea83cd7d01113bdc63fad07b3e8ede2 38Mi images/operator-2.0.35-b101.tar.gz false
downloadAndPush 24 container.repository.cloudera.com/cdp-private/cloudera/cdsw/postgres:2.0.35-b101 cloudera/cdsw/postgres:2.0.35-b101 sha256:5ad1048aa759be53692d611f28ac18151cb9ce1e53a41dbd4195152d2a2fc1d7 468Mi images/postgres-2.0.35-b101.tar.gz false
downloadAndPush 25 container.repository.cloudera.com/cdp-private/cloudera/cdsw/postgres-exporter:2.0.35-b101 cloudera/cdsw/postgres-exporter:2.0.35-b101 sha256:9bd953972fdd9486cc02a7d07fc5ef444c83f1e1a9e12054a3b084ccdd430e30 12Mi images/postgres-exporter-2.0.35-b101.tar.gz false
downloadAndPush 26 container.repository.cloudera.com/cdp-private/cloudera/cdsw/reconciler:2.0.35-b101 cloudera/cdsw/reconciler:2.0.35-b101 sha256:7a1ece5d6706dc996f0bb9d9d5faf9b0604b9bdf6281ff428fa3f17bb74ea0c0 36Mi images/reconciler-2.0.35-b101.tar.gz false
downloadAndPush 27 container.repository.cloudera.com/cdp-private/cloudera/cdsw/runtime-addon-loader:2.0.35-b101 cloudera/cdsw/runtime-addon-loader:2.0.35-b101 sha256:a1404267c69a1685c631bc6fd2f6b201c78a8afc7dafda8f28bab4010194be00 110Mi images/runtime-addon-loader-2.0.35-b101.tar.gz false
downloadAndPush 28 container.repository.cloudera.com/cdp-private/cloudera/cdsw/runtime-manager:2.0.35-b101 cloudera/cdsw/runtime-manager:2.0.35-b101 sha256:826cb04db9178a75220d59b3671536247f2e814632f2a3270fcb131b1dc118ec 45Mi images/runtime-manager-2.0.35-b101.tar.gz false
downloadAndPush 29 container.repository.cloudera.com/cdp-private/cloudera/cdsw/s2i-builder:2.0.35-b101 cloudera/cdsw/s2i-builder:2.0.35-b101 sha256:bc216323ff6527fa7b3c3ca08adab090225bebc0204abeed60dd33737a33f44f 556Mi images/s2i-builder-2.0.35-b101.tar.gz false
downloadAndPush 30 container.repository.cloudera.com/cdp-private/cloudera/cdsw/s2i-client:2.0.35-b101 cloudera/cdsw/s2i-client:2.0.35-b101 sha256:4ca01cc2c80fcfbf51bba0ad1e43dcc1733700972c9707d3e6ae23d835e66428 283Mi images/s2i-client-2.0.35-b101.tar.gz false
downloadAndPush 31 container.repository.cloudera.com/cdp-private/cloudera/cdsw/s2i-git-server:2.0.35-b101 cloudera/cdsw/s2i-git-server:2.0.35-b101 sha256:765ed49e18d1878b26e58c775ee130b66466e87cedc0f73839dfc759229c25a0 260Mi images/s2i-git-server-2.0.35-b101.tar.gz false
downloadAndPush 32 container.repository.cloudera.com/cdp-private/cloudera/cdsw/s2i-queue:2.0.35-b101 cloudera/cdsw/s2i-queue:2.0.35-b101 sha256:acc4cba8696a7b36c876950af5e0afa7ca00e012b73049fe217bfc364e330e53 294Mi images/s2i-queue-2.0.35-b101.tar.gz false
downloadAndPush 33 container.repository.cloudera.com/cdp-private/cloudera/cdsw/s2i-registry:2.0.35-b101 cloudera/cdsw/s2i-registry:2.0.35-b101 sha256:c9ebeac09988464fc40c98e5ec7b9dfd5696281694abd0a78a442d97b43f91ed 182Mi images/s2i-registry-2.0.35-b101.tar.gz false
downloadAndPush 34 container.repository.cloudera.com/cdp-private/cloudera/cdsw/s2i-registry-auth:2.0.35-b101 cloudera/cdsw/s2i-registry-auth:2.0.35-b101 sha256:a22317769ef39999a583b51dd3a113e9720ad5b9362e2118f12b1374d43ed83e 129Mi images/s2i-registry-auth-2.0.35-b101.tar.gz false
downloadAndPush 35 container.repository.cloudera.com/cdp-private/cloudera/cdsw/s2i-server:2.0.35-b101 cloudera/cdsw/s2i-server:2.0.35-b101 sha256:8cf16b789c3c7c46822bc23e3d6e9379ea79a34400498f498855a9be586f5005 36Mi images/s2i-server-2.0.35-b101.tar.gz false
downloadAndPush 36 container.repository.cloudera.com/cdp-private/cloudera/cdsw/sdx-templates:2.0.35-b101 cloudera/cdsw/sdx-templates:2.0.35-b101 sha256:ee756fd9dc817ec6b3744fbac977918aaac9194cc1db02e784dfd3dd8e800a1f 101Mi images/sdx-templates-2.0.35-b101.tar.gz false
downloadAndPush 37 container.repository.cloudera.com/cdp-private/cloudera/cdsw/secret-generator:2.0.35-b101 cloudera/cdsw/secret-generator:2.0.35-b101 sha256:4b48e2abd531b94f4fb57cad25500dcf56e089076f312505c0ca11e23ecc8892 141Mi images/secret-generator-2.0.35-b101.tar.gz false
downloadAndPush 38 container.repository.cloudera.com/cdp-private/cloudera/cdsw/ssh:2.0.35-b101 cloudera/cdsw/ssh:2.0.35-b101 sha256:eee17fba38a62b5f80d744bd2a8f080f0f677e57baa0ffa025584e8060c581d5 5Mi images/ssh-2.0.35-b101.tar.gz false
downloadAndPush 39 container.repository.cloudera.com/cdp-private/cloudera/cdsw/tcp-ingress-controller:2.0.35-b101 cloudera/cdsw/tcp-ingress-controller:2.0.35-b101 sha256:79a1349261158833c1d5032349bddec13492bdc256d9e0e5544925d5374dc200 11Mi images/tcp-ingress-controller-2.0.35-b101.tar.gz false
downloadAndPush 40 container.repository.cloudera.com/cdp-private/cloudera/cdsw/upgrade-db:2.0.35-b101 cloudera/cdsw/upgrade-db:2.0.35-b101 sha256:534e41ce3e0d82835ff0d36db8ed0008a952008e4ffc97a0a8a715eea7b82de3 573Mi images/upgrade-db-2.0.35-b101.tar.gz false
downloadAndPush 41 container.repository.cloudera.com/cdp-private/cloudera/cdsw/usage-reporter:2.0.35-b101 cloudera/cdsw/usage-reporter:2.0.35-b101 sha256:9fe65396569125f7dbfa914d2fba0b4299617da5f77440eea91ac0103580820f 110Mi images/usage-reporter-2.0.35-b101.tar.gz false
downloadAndPush 42 container.repository.cloudera.com/cdp-private/cloudera/cdsw/vfs:2.0.35-b101 cloudera/cdsw/vfs:2.0.35-b101 sha256:52a9aac7fa0fb947f44e77ba6b3ead1d6937e0f7de9403f6e15502c5db56c2af 264Mi images/vfs-2.0.35-b101.tar.gz false
downloadAndPush 43 container.repository.cloudera.com/cdp-private/cloudera/cdsw/web:2.0.35-b101 cloudera/cdsw/web:2.0.35-b101 sha256:48bf26b2058e4c8c58f3277b65d04e6b803796ad41a57a334f45e61cf291875e 1Gi images/web-2.0.35-b101.tar.gz false
downloadAndPush 44 container.repository.cloudera.com/cdp-private/cloudera/cdv/cdwdataviz:7.0.5-b53 cloudera/cdv/cdwdataviz:7.0.5-b53 sha256:e461502a2ebce8fe59d3e4e7b5b8d6f907cebb37a7355662c4f2b89d33c6d1ef 2Gi images/cdwdataviz-7.0.5-b53.tar.gz false
downloadAndPush 45 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/cldr-kubectl:1.24.2 cloudera_thirdparty/cldr-kubectl:1.24.2 sha256:25e2886e571039b53684b0735176c0c3abd73fdd2f96c60a483b1b5ca5cd0131 141Mi images/cldr-kubectl-1.24.2.tar.gz false
downloadAndPush 46 container.repository.cloudera.com/cdp-private/cloudera/cluster-access-manager:0.12.0-b14 cloudera/cluster-access-manager:0.12.0-b14 sha256:49059ef23ad04b4fead0387c85e8d8f5b954a1c0e56719aa7b4d9e6afda6bc8f 161Mi images/cluster-access-manager-0.12.0-b14.tar.gz false
downloadAndPush 47 container.repository.cloudera.com/cdp-private/cloudera/cloud/cluster-proxy-private:1.0.6-b42 cloudera/cloud/cluster-proxy-private:1.0.6-b42 sha256:578df8ad2b23dd3fb19f8af306ad938b8adbf2e2878e8253c8b2a38be8665830 525Mi images/cluster-proxy-private-1.0.6-b42.tar.gz false
downloadAndPush 48 container.repository.cloudera.com/cdp-private/cloudera/cm-health-exporter:1.5.0-b32 cloudera/cm-health-exporter:1.5.0-b32 sha256:79dc693f1296a44f78d351f9ce55c5f5ca32145a6233913ae606452efe996a3a 137Mi images/cm-health-exporter-1.5.0-b32.tar.gz false
downloadAndPush 49 container.repository.cloudera.com/cdp-private/cloudera/cdsw/ml-runtime-addon-hadoop-cli-24102687-7.1.7-1000:1.1.0-b1 cloudera/cdsw/ml-runtime-addon-hadoop-cli-24102687-7.1.7-1000:1.1.0-b1 sha256:2ac0de67d86c0f35a5f0435f1a0dbce3dc1a9c8f2e65840f643e7dcdf6fb82fe 2Gi images/ml-runtime-addon-hadoop-cli-24102687-7.1.7-1000-1.1.0-b1.tar.gz false
downloadAndPush 50 container.repository.cloudera.com/cdp-private/cloudera/cdsw/ml-runtime-addon-spark2.4.7-7.1.7.1000-1.18.2:1.1.0-b4 cloudera/cdsw/ml-runtime-addon-spark2.4.7-7.1.7.1000-1.18.2:1.1.0-b4 sha256:02a5afbdafbf74045e599206eb62c5e187d7a59d2f83569273d2f220d1c495b8 2Gi images/ml-runtime-addon-spark2.4.7-7.1.7.1000-1.18.2-1.1.0-b4.tar.gz false
downloadAndPush 51 container.repository.cloudera.com/cdp-private/cloudera/cdsw/ml-runtime-addon-spark3.2.1-7.1.7.1000-1.18.2:1.1.0-b4 cloudera/cdsw/ml-runtime-addon-spark3.2.1-7.1.7.1000-1.18.2:1.1.0-b4 sha256:3de01bc38134c6af5c3f101a050212a226aa1b522c14988885751ad662e8948a 1Gi images/ml-runtime-addon-spark3.2.1-7.1.7.1000-1.18.2-1.1.0-b4.tar.gz false
downloadAndPush 52 container.repository.cloudera.com/cdp-private/cloudera/cdsw/engine:16-cml-2022.01-2 cloudera/cdsw/engine:16-cml-2022.01-2 sha256:e9d05b354e684971fb683294cf4bc174f13bb0af6a275cbccf5c8b7a9f21d79d 10Gi images/engine-16-cml-2022.01-2.tar.gz false
downloadAndPush 53 container.repository.cloudera.com/cdp-private/cloudera/compute-operator:1.6.0-b58 cloudera/compute-operator:1.6.0-b58 sha256:8b1353f6ca199067e7e25099905d2cffe3722dac279f5adba505aefeb04ad78e 306Mi images/compute-operator-1.6.0-b58.tar.gz false
downloadAndPush 54 container.repository.cloudera.com/cdp-private/cloudera/compute-usage-monitor:1.6.0-b58 cloudera/compute-usage-monitor:1.6.0-b58 sha256:3cb626a2855bb09feb697944e037276719cdf609dc0f1444cce5d3e3daf9322b 1Gi images/compute-usage-monitor-1.6.0-b58.tar.gz false
downloadAndPush 55 container.repository.cloudera.com/cdp-private/cloudera/configuration-sidecar:1.6.0-b58 cloudera/configuration-sidecar:1.6.0-b58 sha256:78c4a84c779df7510f71720a8481cd9111a1afb00701df240d79539924900195 364Mi images/configuration-sidecar-1.6.0-b58.tar.gz false
downloadAndPush 56 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/sig-storage/csi-attacher:v3.4.0 cloudera_thirdparty/sig-storage/csi-attacher:v3.4.0 sha256:03e115718d258479ce19feeb9635215f98e5ad1475667b4395b79e68caf129a6 52Mi images/csi-attacher-v3.4.0.tar.gz false
downloadAndPush 57 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/sig-storage/csi-node-driver-registrar:v2.5.0 cloudera_thirdparty/sig-storage/csi-node-driver-registrar:v2.5.0 sha256:cb03930a2bd4247929205f328d7c1b7d9594d7586813d4c108c43dc852fad219 18Mi images/csi-node-driver-registrar-v2.5.0.tar.gz false
downloadAndPush 58 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/sig-storage/csi-provisioner:v2.1.2 cloudera_thirdparty/sig-storage/csi-provisioner:v2.1.2 sha256:0f0a0f79907682a730c965cac0f5dcc3d7b20e0fd03e0ef197bc91f95323da36 49Mi images/csi-provisioner-v2.1.2.tar.gz false
downloadAndPush 59 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/sig-storage/csi-resizer:v1.2.0 cloudera_thirdparty/sig-storage/csi-resizer:v1.2.0 sha256:0aa9629e1508bd8d91b24a8cd98a75bbba1ed2951722432fcbf7ee47751b6719 51Mi images/csi-resizer-v1.2.0.tar.gz false
downloadAndPush 60 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/sig-storage/csi-snapshotter:v3.0.3 cloudera_thirdparty/sig-storage/csi-snapshotter:v3.0.3 sha256:000846ee533565b30a0afba057ea5af51d4956b0fc6918d7e105b4859f16cad5 45Mi images/csi-snapshotter-v3.0.3.tar.gz false
downloadAndPush 61 container.repository.cloudera.com/cdp-private/cloudera/das:2022.0.11.1-15 cloudera/das:2022.0.11.1-15 sha256:694cbfad77423f90fd438067e8140734b807365f1002b931785669e525f4e5dc 2Gi images/das-2022.0.11.1-15.tar.gz false
downloadAndPush 62 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-admission-controller:1.18.2-b70 cloudera/dex/dex-admission-controller:1.18.2-b70 sha256:eccbc6a8849ce15e9f151235bc5c7a9716cd55f3ba289893fff36ca5b10c9ef1 110Mi images/dex-admission-controller-1.18.2-b70.tar.gz false
downloadAndPush 63 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-airflow-7.2.15.0:1.18.2-b70 cloudera/dex/dex-airflow-7.2.15.0:1.18.2-b70 sha256:0ea25cf1a0788420fc2f3365431f127ca3846ccef523bafb91be00ce458d70b8 3Gi images/dex-airflow-7.2.15.0-1.18.2-b70.tar.gz false
downloadAndPush 64 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-airflow-api-server-7.2.15.0:1.18.2-b70 cloudera/dex/dex-airflow-api-server-7.2.15.0:1.18.2-b70 sha256:a5f80ce6532f100db6ea05cdb15bd0c20ef62bc66368ef575d00248a232492a2 3Gi images/dex-airflow-api-server-7.2.15.0-1.18.2-b70.tar.gz false
downloadAndPush 65 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-airflow-connections-7.2.15.0:1.18.2-b70 cloudera/dex/dex-airflow-connections-7.2.15.0:1.18.2-b70 sha256:382a902a67343c8dbac48e6bf6438a3419c2362f6642c2ee66229899d97f75f5 1Gi images/dex-airflow-connections-7.2.15.0-1.18.2-b70.tar.gz false
downloadAndPush 66 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-configs-manager:1.18.2-b70 cloudera/dex/dex-configs-manager:1.18.2-b70 sha256:a67058f42e3c3deea479857654a6aae54c21e7f5a9ad0c123d742db6667e4352 161Mi images/dex-configs-manager-1.18.2-b70.tar.gz false
downloadAndPush 67 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-configs-templates-init:1.18.2-b70 cloudera/dex/dex-configs-templates-init:1.18.2-b70 sha256:a6d8f72e2fd4e563c6dcf5cef2a268029d905103c1b1aaee545af7d17ef9f228 7Mi images/dex-configs-templates-init-1.18.2-b70.tar.gz false
downloadAndPush 68 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-configs-templates-init-pvc:1.18.2-b70 cloudera/dex/dex-configs-templates-init-pvc:1.18.2-b70 sha256:abeff1ddbbc1077b8dd05d07ed16d5e4ccb0347dd71447cf109b7e97df87f9f2 7Mi images/dex-configs-templates-init-pvc-1.18.2-b70.tar.gz false
downloadAndPush 69 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-cp:1.18.2-b70 cloudera/dex/dex-cp:1.18.2-b70 sha256:38d9b81be1f33296aeca5b48b68c9d7d29e67067b5809d725de5d62a98c23058 521Mi images/dex-cp-1.18.2-b70.tar.gz false
downloadAndPush 70 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-diagnostics:1.18.2-b70 cloudera/dex/dex-diagnostics:1.18.2-b70 sha256:e6c6fe5caf929044e100beeef749bf5a0f7bea3d0985bf25b86385653873dce2 65Mi images/dex-diagnostics-1.18.2-b70.tar.gz false
downloadAndPush 71 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-downloads:1.18.2-b70 cloudera/dex/dex-downloads:1.18.2-b70 sha256:d22bd50a73220c238fe8f1f735ecc07eef091064d739c3394a4e1a2ef60e21bc 550Mi images/dex-downloads-1.18.2-b70.tar.gz false
downloadAndPush 72 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-efs-init:1.18.2-b70 cloudera/dex/dex-efs-init:1.18.2-b70 sha256:a31725ed7c5d9a49059e37731d6ed32a62895af31b17c7c9e794181ea586ae54 98Mi images/dex-efs-init-1.18.2-b70.tar.gz false
downloadAndPush 73 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-eventlog-reader:1.18.2-b70 cloudera/dex/dex-eventlog-reader:1.18.2-b70 sha256:ed042194336b8de63fe87d58ba2f0ff6ddfde4e514a028a49157860fe98c2808 7Mi images/dex-eventlog-reader-1.18.2-b70.tar.gz false
downloadAndPush 74 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-grafana:1.18.2-b70 cloudera/dex/dex-grafana:1.18.2-b70 sha256:1b608c56eb55f696aded9e24bb85fca5b76af313f7edade5f0c7a4ce8fba3c22 223Mi images/dex-grafana-1.18.2-b70.tar.gz false
downloadAndPush 75 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-k8s-events-logger:1.18.2-b70 cloudera/dex/dex-k8s-events-logger:1.18.2-b70 sha256:c06a797bf0361177dc1933b2c747530592a5cc532abe4efd1b0a3328febb75c5 661Mi images/dex-k8s-events-logger-1.18.2-b70.tar.gz false
downloadAndPush 76 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-knox:1.18.2-b70 cloudera/dex/dex-knox:1.18.2-b70 sha256:090a9b8ee2adc80f3c2682d0b0b094d373938ad470a5c09dcea3d0b7c775e327 1Gi images/dex-knox-1.18.2-b70.tar.gz false
downloadAndPush 77 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-livy-server-2.4.8-7.2.15.0:1.18.2-b70 cloudera/dex/dex-livy-server-2.4.8-7.2.15.0:1.18.2-b70 sha256:2667ea3bf06a973ca3cc987ad7e18dbe8c0949314b9132132851fe86d3913c42 2Gi images/dex-livy-server-2.4.8-7.2.15.0-1.18.2-b70.tar.gz false
downloadAndPush 78 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-livy-server-3.2.0-7.2.15.0:1.18.2-b70 cloudera/dex/dex-livy-server-3.2.0-7.2.15.0:1.18.2-b70 sha256:ba4f57718104648a39eb25203d994affc8b1e92ed47ce5dc0a323aa05b3292d2 1Gi images/dex-livy-server-3.2.0-7.2.15.0-1.18.2-b70.tar.gz false
downloadAndPush 79 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-pipelines-api-server:1.18.2-b70 cloudera/dex/dex-pipelines-api-server:1.18.2-b70 sha256:baec5a68c34695e5ef7bd6588f9165c95a3ab2715e9b5dce4066cf927a3ec57b 383Mi images/dex-pipelines-api-server-1.18.2-b70.tar.gz false
downloadAndPush 80 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-airflow-7.1.7.1000:1.18.2-b70 cloudera/dex/dex-airflow-7.1.7.1000:1.18.2-b70 sha256:612279ad73f7c4da8f2019e05787241598dd7daad33d39275bfd811b80774d3e 3Gi images/dex-airflow-7.1.7.1000-1.18.2-b70.tar.gz false
downloadAndPush 81 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-airflow-api-server-7.1.7.1000:1.18.2-b70 cloudera/dex/dex-airflow-api-server-7.1.7.1000:1.18.2-b70 sha256:7705b5694e8d45903c62c631e087305ed10c5d194c758fbb6210ea8143727299 3Gi images/dex-airflow-api-server-7.1.7.1000-1.18.2-b70.tar.gz false
downloadAndPush 82 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-airflow-connections-7.1.7.1000:1.18.2-b70 cloudera/dex/dex-airflow-connections-7.1.7.1000:1.18.2-b70 sha256:9aec562fb0145a195dda5d4a1a38f6238b1f16fcfc942420b05bdf2e2366238a 1Gi images/dex-airflow-connections-7.1.7.1000-1.18.2-b70.tar.gz false
downloadAndPush 83 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-livy-server-2.4.7-7.1.7.1000:1.18.2-b70 cloudera/dex/dex-livy-server-2.4.7-7.1.7.1000:1.18.2-b70 sha256:8697b1b60880a5e698c3cd6461f10513ab44e3bfe4ce86a55b716187ece2ee84 2Gi images/dex-livy-server-2.4.7-7.1.7.1000-1.18.2-b70.tar.gz false
downloadAndPush 84 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-livy-server-3.2.1-7.1.7.1000:1.18.2-b70 cloudera/dex/dex-livy-server-3.2.1-7.1.7.1000:1.18.2-b70 sha256:422f7a3bc5a3e7bb9053f0c05ef0c0c9b5499b32d7febf5aa05ad7d1f154cace 1Gi images/dex-livy-server-3.2.1-7.1.7.1000-1.18.2-b70.tar.gz false
downloadAndPush 85 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-safari-7.1.7.1000:1.18.2-b70 cloudera/dex/dex-safari-7.1.7.1000:1.18.2-b70 sha256:913dec3006f7944b4612b69bbe39d721fdeea771606a1e8c7fd76eca9fb1216c 2Gi images/dex-safari-7.1.7.1000-1.18.2-b70.tar.gz false
downloadAndPush 86 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-spark-history-server-2.4.7-7.1.7.1000:1.18.2-b70 cloudera/dex/dex-spark-history-server-2.4.7-7.1.7.1000:1.18.2-b70 sha256:1b09078dd59d1e4fd253937ca91084f865834a6edd8bcda1ae1a8335526ca4ea 1Gi images/dex-spark-history-server-2.4.7-7.1.7.1000-1.18.2-b70.tar.gz false
downloadAndPush 87 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-spark-runtime-2.4.7-7.1.7.1000:1.18.2-b70 cloudera/dex/dex-spark-runtime-2.4.7-7.1.7.1000:1.18.2-b70 sha256:78a9aad35c64b36dc2648a3f7cd0b71be59bb71aefc9300be726c03bd9b06892 2Gi images/dex-spark-runtime-2.4.7-7.1.7.1000-1.18.2-b70.tar.gz false
downloadAndPush 88 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-spark-history-server-3.2.1-7.1.7.1000:1.18.2-b70 cloudera/dex/dex-spark-history-server-3.2.1-7.1.7.1000:1.18.2-b70 sha256:c596686dd375048f783ea6ad307af5a47438d18730629be53f03ce6cdecc9d02 1Gi images/dex-spark-history-server-3.2.1-7.1.7.1000-1.18.2-b70.tar.gz false
downloadAndPush 89 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-spark-runtime-3.2.1-7.1.7.1000:1.18.2-b70 cloudera/dex/dex-spark-runtime-3.2.1-7.1.7.1000:1.18.2-b70 sha256:95bc22c13ef3ab75fa9e8f6568d7baeaccd7a62f51af9f3ae4c98531e135d9cf 1Gi images/dex-spark-runtime-3.2.1-7.1.7.1000-1.18.2-b70.tar.gz false
downloadAndPush 90 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-rss:1.18.2-b70 cloudera/dex/dex-rss:1.18.2-b70 sha256:12196e2888a63cc323a28f77049f6aa6a462fcea1a30e09703ed68af12835405 602Mi images/dex-rss-1.18.2-b70.tar.gz false
downloadAndPush 91 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-runtime-api-kinit:1.18.2-b70 cloudera/dex/dex-runtime-api-kinit:1.18.2-b70 sha256:28f79b9e01fd8084576801b11368e1f138cb757e54906887d9557524dec84a52 227Mi images/dex-runtime-api-kinit-1.18.2-b70.tar.gz false
downloadAndPush 92 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-runtime-api-server:1.18.2-b70 cloudera/dex/dex-runtime-api-server:1.18.2-b70 sha256:e40f38cba839154b4bc8da7152569ca15f6885f61ea5a602f863e879451ceda5 644Mi images/dex-runtime-api-server-1.18.2-b70.tar.gz false
downloadAndPush 93 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-runtime-db-hook:1.18.2-b70 cloudera/dex/dex-runtime-db-hook:1.18.2-b70 sha256:64913a22ccd8391918dfdf4b5533dd5fae67445bf1f23614b975fa862b92bf31 229Mi images/dex-runtime-db-hook-1.18.2-b70.tar.gz false
downloadAndPush 94 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-runtime-management-authz:1.18.2-b70 cloudera/dex/dex-runtime-management-authz:1.18.2-b70 sha256:b02a7e178dd4997d34070cb3029de1e927a72113915d344c8c20f4e64f5bb810 180Mi images/dex-runtime-management-authz-1.18.2-b70.tar.gz false
downloadAndPush 95 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-runtime-management-metadata-proxy:1.18.2-b70 cloudera/dex/dex-runtime-management-metadata-proxy:1.18.2-b70 sha256:3141f80ee61d04698334f8655519f1436d2d6ef4914de328ffe9d4b974d53e9f 167Mi images/dex-runtime-management-metadata-proxy-1.18.2-b70.tar.gz false
downloadAndPush 96 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-runtime-management-metadata-proxy-templates-init:1.18.2-b70 cloudera/dex/dex-runtime-management-metadata-proxy-templates-init:1.18.2-b70 sha256:b695dbf6b0cada028c6fcd2907be75eb9a0e0bdfb7c0b8d72721f4dc7bbccf85 5Mi images/dex-runtime-management-metadata-proxy-templates-init-1.18.2-b70.tar.gz false
downloadAndPush 97 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-runtime-management-server:1.18.2-b70 cloudera/dex/dex-runtime-management-server:1.18.2-b70 sha256:7e374cc0b78688117350c3b07095ea8cd86f5c6a263c5198a8a5063e16b8c3b6 232Mi images/dex-runtime-management-server-1.18.2-b70.tar.gz false
downloadAndPush 98 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-runtime-python-builder:1.18.2-b70 cloudera/dex/dex-runtime-python-builder:1.18.2-b70 sha256:a3ded89fcf81ae64af505a050b94b8bffe718fcc5b3240bd015d199e5f7b8be2 609Mi images/dex-runtime-python-builder-1.18.2-b70.tar.gz false
downloadAndPush 99 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-safari-7.2.15.0:1.18.2-b70 cloudera/dex/dex-safari-7.2.15.0:1.18.2-b70 sha256:16cebd07fa5710a8a7c3afbd0d42385444afd1eecc9caebca41899d6696f82c1 2Gi images/dex-safari-7.2.15.0-1.18.2-b70.tar.gz false
downloadAndPush 100 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-shs-init:1.18.2-b70 cloudera/dex/dex-shs-init:1.18.2-b70 sha256:259a24a237d27b3af88c1d7eafb577890ea51d05eeb7f9938687c86290bda348 105Mi images/dex-shs-init-1.18.2-b70.tar.gz false
downloadAndPush 101 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-spark-history-server-2.4.8-7.2.15.0:1.18.2-b70 cloudera/dex/dex-spark-history-server-2.4.8-7.2.15.0:1.18.2-b70 sha256:09f407844c15f419b6e359a9faa83c7ebb2093b86df1d15eaead502471a0246e 2Gi images/dex-spark-history-server-2.4.8-7.2.15.0-1.18.2-b70.tar.gz false
downloadAndPush 102 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-spark-runtime-2.4.8-7.2.15.0:1.18.2-b70 cloudera/dex/dex-spark-runtime-2.4.8-7.2.15.0:1.18.2-b70 sha256:4d05b41e1f62106a058de2e6e5f37723515d0f88d2963a5703adc0b725035262 2Gi images/dex-spark-runtime-2.4.8-7.2.15.0-1.18.2-b70.tar.gz false
downloadAndPush 103 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-spark-history-server-3.2.0-7.2.15.0:1.18.2-b70 cloudera/dex/dex-spark-history-server-3.2.0-7.2.15.0:1.18.2-b70 sha256:3dfd13a574b1a848def6af6008f373cfd8990ef0f6566c2b5396b05f8e5b9d76 2Gi images/dex-spark-history-server-3.2.0-7.2.15.0-1.18.2-b70.tar.gz false
downloadAndPush 104 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-spark-runtime-3.2.0-7.2.15.0:1.18.2-b70 cloudera/dex/dex-spark-runtime-3.2.0-7.2.15.0:1.18.2-b70 sha256:92c9497880569ecdd1f279d84b26cd5ae529ef570d75cff37e033c5a132364fc 1Gi images/dex-spark-runtime-3.2.0-7.2.15.0-1.18.2-b70.tar.gz false
downloadAndPush 105 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-tgtgen-reconciler:1.18.2-b70 cloudera/dex/dex-tgtgen-reconciler:1.18.2-b70 sha256:d989ec338e3da083fcd836d4645fa591094902c92be5f49923df3fb48e72b9c4 116Mi images/dex-tgtgen-reconciler-1.18.2-b70.tar.gz false
downloadAndPush 106 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-tgtgen-templates-init:1.18.2-b70 cloudera/dex/dex-tgtgen-templates-init:1.18.2-b70 sha256:ba5d445f11d97a2ea97b360cedb595d453077c0af29bf386dd3fb15844d8791b 5Mi images/dex-tgtgen-templates-init-1.18.2-b70.tar.gz false
downloadAndPush 107 container.repository.cloudera.com/cdp-private/cloudera/dex/dex-workspace-init:1.18.2-b70 cloudera/dex/dex-workspace-init:1.18.2-b70 sha256:48e3c283aa0e4c64850332cfa4687be7311f13ec5c404696af176dcce3713f07 99Mi images/dex-workspace-init-1.18.2-b70.tar.gz false
downloadAndPush 108 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/amazon/aws-node-termination-handler:v1.5.0 cloudera_thirdparty/amazon/aws-node-termination-handler:v1.5.0 sha256:9672d174fe482cb0bb25dbf6eebbaa7594b323e8e8ba7440f9ecf20d2c58eaa9 36Mi images/aws-node-termination-handler-v1.5.0.tar.gz false
downloadAndPush 109 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/busybox:1.30 cloudera_thirdparty/busybox:1.30 sha256:64f5d945efcc0f39ab11b3cd4ba403cc9fefe1fa3613123ca016cf3708e8cafb 1Mi images/busybox-1.30.tar.gz false
downloadAndPush 110 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/calico/cni:v3.16.1 cloudera_thirdparty/calico/cni:v3.16.1 sha256:4ab373b1fac4c3dd2a948d26799009c47ce84668b7931eb83e2feb09b94cf6cf 127Mi images/cni-v3.16.1.tar.gz false
downloadAndPush 111 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/calico/kube-controllers:v3.16.1 cloudera_thirdparty/calico/kube-controllers:v3.16.1 sha256:03feeb39a75a335d5265a43d121d84d539b9db7ed2c85db04652434d0dc59de5 50Mi images/kube-controllers-v3.16.1.tar.gz false
downloadAndPush 112 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/calico/node:v3.16.1 cloudera_thirdparty/calico/node:v3.16.1 sha256:0f351f210d5e10e83519f2587ef39ef8b38184a91784240b3932c91bb0654a11 156Mi images/node-v3.16.1.tar.gz false
downloadAndPush 113 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/calico/pod2daemon-flexvol:v3.16.1 cloudera_thirdparty/calico/pod2daemon-flexvol:v3.16.1 sha256:4cbe1ed86c35615f0255388fb6957aa9e2872b1919e90eb37cb1404954d42a5d 21Mi images/pod2daemon-flexvol-v3.16.1.tar.gz false
downloadAndPush 114 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/calico/typha:v3.16.1 cloudera_thirdparty/calico/typha:v3.16.1 sha256:c5132b2bf06f61c7eca572c9adc7d3d63c81d3eebc78c1012c3e55d6fd8838aa 49Mi images/typha-v3.16.1.tar.gz false
downloadAndPush 115 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/autoscaling/cluster-autoscaler:v1.19.1 cloudera_thirdparty/autoscaling/cluster-autoscaler:v1.19.1 sha256:55f35bddf3b8b21a2ad2da4eeb5f870d5ef30d1ca57e1e5c09a9e5b60fcd74ab 86Mi images/cluster-autoscaler-v1.19.1.tar.gz false
downloadAndPush 116 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/jimmidyson/configmap-reload:v0.3.0 cloudera_thirdparty/jimmidyson/configmap-reload:v0.3.0 sha256:7ec24a279487c2a51c62c42efd554a99b06916f3b91efa4591871b91ef904a35 9Mi images/configmap-reload-v0.3.0.tar.gz false
downloadAndPush 117 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/external_storage/efs-provisioner:v2.4.0-cldr-3 cloudera_thirdparty/external_storage/efs-provisioner:v2.4.0-cldr-3 sha256:bcab80cc2ebfe50ac2e827452b7e963d2478213bc77da71f31d222b0ff3babf7 45Mi images/efs-provisioner-v2.4.0-cldr-3.tar.gz false
downloadAndPush 118 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/rhel8/mysql-80:1-138 cloudera_thirdparty/rhel8/mysql-80:1-138 sha256:d42f3bb9aced8a248becede2651f5c361d117ac1de6aca594962c6143a86206d 571Mi images/mysql-80-1-138.tar.gz false
downloadAndPush 119 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/fluent-bit:v1.9.8 cloudera_thirdparty/fluent-bit:v1.9.8 sha256:e1a4b9b9084be25c2015018d93b39afaa752164cf31cb4889c0e437eb1e86d90 219Mi images/fluent-bit-v1.9.8.tar.gz false
downloadAndPush 120 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/fluentd:v1.15.2-cldr-3 cloudera_thirdparty/fluentd:v1.15.2-cldr-3 sha256:fd1b510b05c7ed794c4f27f74758cb412340f1be6563832c47527f0e8d756a54 306Mi images/fluentd-v1.15.2-cldr-3.tar.gz false
downloadAndPush 121 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/fluent/fluentd:v1.15.0-cdp-0.1.18 cloudera_thirdparty/fluent/fluentd:v1.15.0-cdp-0.1.18 sha256:2d2f63a62f41e71d605761dc936331b938c83d699b0f69b80814612e3c7cffd1 391Mi images/fluentd-v1.15.0-cdp-0.1.18.tar.gz false
downloadAndPush 122 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/heapster-amd64:v1.5.3 cloudera_thirdparty/heapster-amd64:v1.5.3 sha256:f57c75cd7b0aa80b70947ea614c29ad04617dade823ec9b25fcadbed38ddce1c 71Mi images/heapster-amd64-v1.5.3.tar.gz false
downloadAndPush 123 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/heapster-influxdb-amd64:v1.3.3 cloudera_thirdparty/heapster-influxdb-amd64:v1.3.3 sha256:577260d221dbb1be2d83447402d0d7c5e15501a89b0e2cc1961f0b24ed56c77c 11Mi images/heapster-influxdb-amd64-v1.3.3.tar.gz false
downloadAndPush 124 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/ingress-nginx-controller:v1.3.1-cldr-1 cloudera_thirdparty/ingress-nginx-controller:v1.3.1-cldr-1 sha256:1a29ae6d3bc03a6981beb643e3c7cad681840ffb6e7c072ccdc959617c17146f 260Mi images/ingress-nginx-controller-v1.3.1-cldr-1.tar.gz false
downloadAndPush 125 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/istio/operator:1.11.2 cloudera_thirdparty/istio/operator:1.11.2 sha256:b9e596a5419ccbf83884c1972768b6e8b474f6e7d72cb6757e8c6e00b2dd30e4 180Mi images/operator-1.11.2.tar.gz false
downloadAndPush 126 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/istio/pilot:1.11.2 cloudera_thirdparty/istio/pilot:1.11.2 sha256:e7b02e597e8f723dfb1edf1cba45af75e8d14ee71bb2d436af3ff4980a6b57e7 180Mi images/pilot-1.11.2.tar.gz false
downloadAndPush 127 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/istio/proxyv2:1.11.2 cloudera_thirdparty/istio/proxyv2:1.11.2 sha256:a78f2ee7a1d7f02e868fa8359a774a58d946d42db27542215bafb51a8385f94b 239Mi images/proxyv2-1.11.2.tar.gz false
downloadAndPush 128 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/quay.io/coreos/kube-state-metrics:v1.9.3 cloudera_thirdparty/quay.io/coreos/kube-state-metrics:v1.9.3 sha256:ce8abbf0c1698da70bf04a9be82195ec2c83b0b5cc26e4c165d215ede3b81258 31Mi images/kube-state-metrics-v1.9.3.tar.gz false
downloadAndPush 129 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/kubernetesui/dashboard:v2.2.0 cloudera_thirdparty/kubernetesui/dashboard:v2.2.0 sha256:5c4ee6ca42ce28fd6126e0fcd4f87dee2854593ae3119993a0bbdf997d34d579 214Mi images/dashboard-v2.2.0.tar.gz false
downloadAndPush 130 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/kubernetesui/metrics-scraper:v1.0.6 cloudera_thirdparty/kubernetesui/metrics-scraper:v1.0.6 sha256:48d79e554db69811a12d0300d8ad5da158d134d575d8268902430d824143eb49 32Mi images/metrics-scraper-v1.0.6.tar.gz false
downloadAndPush 131 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/prom/node-exporter:v0.18.1 cloudera_thirdparty/prom/node-exporter:v0.18.1 sha256:e5a616e4b9cf68dfcad7782b78e118be4310022e874d52da85c55923fb615f87 21Mi images/node-exporter-v0.18.1.tar.gz false
downloadAndPush 132 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/prom/pushgateway:v1.0.0 cloudera_thirdparty/prom/pushgateway:v1.0.0 sha256:a14a86875d6272e0ab7b653f0d959b946974a385c6c5fe0e7c80d18f6fe9c2ff 18Mi images/pushgateway-v1.0.0.tar.gz false
downloadAndPush 133 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-configmap-autoupdater:3255d90e936dc3978d2ea703523011344fcb2e8f cloudera/thunderhead-configmap-autoupdater:3255d90e936dc3978d2ea703523011344fcb2e8f sha256:610fced339ce57e02d23eed0a5f1e367fcab63461f7415234e92489b41ae1a1f 46Mi images/thunderhead-configmap-autoupdater-3255d90e936dc3978d2ea703523011344fcb2e8f.tar.gz false
downloadAndPush 134 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-configtemplate:785be707c881f1ccbced4e992401d7d400990e51 cloudera/thunderhead-configtemplate:785be707c881f1ccbced4e992401d7d400990e51 sha256:e093f97d0eaf0fcc3121130314727c616cf56c16d6a87a4666c5039682c66436 230Mi images/thunderhead-configtemplate-785be707c881f1ccbced4e992401d7d400990e51.tar.gz false
downloadAndPush 135 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-metering-heartbeat-application:1.0.0-b5733 cloudera/thunderhead-metering-heartbeat-application:1.0.0-b5733 sha256:1c5610cd6198e2dda048c60cfd224f4a5a8004ec4edb078891f3f4a0e3f8649f 59Mi images/thunderhead-metering-heartbeat-application-1.0.0-b5733.tar.gz false
downloadAndPush 136 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-tgtgenerator:0833c1aee54bb07457f520b205dfe2f173258388 cloudera/thunderhead-tgtgenerator:0833c1aee54bb07457f520b205dfe2f173258388 sha256:9ca6425815747eec94aa96c8c85c30285f8783a6c054148d8bc8186ba1cd81b4 315Mi images/thunderhead-tgtgenerator-0833c1aee54bb07457f520b205dfe2f173258388.tar.gz false
downloadAndPush 137 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-tgtloader:d8c14c33407468d1908c00d129d5530e77f90df0 cloudera/thunderhead-tgtloader:d8c14c33407468d1908c00d129d5530e77f90df0 sha256:4caf4d6b009da8c705a17c2565a6d6c5eaf1f0dcc65f367ed64731a3b80cd39c 12Mi images/thunderhead-tgtloader-d8c14c33407468d1908c00d129d5530e77f90df0.tar.gz false
downloadAndPush 138 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/ubi-prometheus:v2.15.2 cloudera_thirdparty/ubi-prometheus:v2.15.2 sha256:61db14a6b98843b95ca54e7499d13f9d4231f2d01fea72f8647ff8c3d3e058a2 259Mi images/ubi-prometheus-v2.15.2.tar.gz false
downloadAndPush 139 container.repository.cloudera.com/cdp-private/cloudera/yunikorn-admission:0.12.2-b52 cloudera/yunikorn-admission:0.12.2-b52 sha256:aab90ffcb51e1e69a06bf80b18c621c4b748840159008fb1aef3ed6ca79afa29 234Mi images/yunikorn-admission-0.12.2-b52.tar.gz false
downloadAndPush 140 container.repository.cloudera.com/cdp-private/cloudera/yunikorn-scheduler:0.12.2-b52 cloudera/yunikorn-scheduler:0.12.2-b52 sha256:47c3b1ae6500a98b461006c2c0bc0b1b6d1115bc68ae2802c9785cb2aa8d325d 250Mi images/yunikorn-scheduler-0.12.2-b52.tar.gz false
downloadAndPush 141 container.repository.cloudera.com/cdp-private/cloudera/yunikorn-web:0.12.2-b52 cloudera/yunikorn-web:0.12.2-b52 sha256:3e5200596c60867fed059ebc178ed030d33580871671781d6680eb3ac1c06ecb 280Mi images/yunikorn-web-0.12.2-b52.tar.gz false
downloadAndPush 142 container.repository.cloudera.com/cdp-private/cloudera/diagnostic-data-generator:1.6.0-b58 cloudera/diagnostic-data-generator:1.6.0-b58 sha256:d8a62ae6a86f0e3ab1074ec64f9d259bef77d2968ee53e381521eeae929ba2fd 775Mi images/diagnostic-data-generator-1.6.0-b58.tar.gz false
downloadAndPush 143 container.repository.cloudera.com/cdp-private/cloudera/diagnostic-tools:1.6.0-b58 cloudera/diagnostic-tools:1.6.0-b58 sha256:2caf002afc2ad29566b7ef92035192698408b3c00eec94bbfaf966d494dbef14 1Gi images/diagnostic-tools-1.6.0-b58.tar.gz false
downloadAndPush 144 container.repository.cloudera.com/cdp-private/cloudera/dmx-app:1.5.0-b18 cloudera/dmx-app:1.5.0-b18 sha256:11232f5603960749c9b93eacf0c0f8c5a59024d0f9f9612c61933e31ffbf4f24 976Mi images/dmx-app-1.5.0-b18.tar.gz false
downloadAndPush 145 container.repository.cloudera.com/cdp-private/cloudera/dmx-web:1.5.0-b18 cloudera/dmx-web:1.5.0-b18 sha256:0a69860b723fb4cdd58fa064ad9c6fb45599a8882d096f0d1e0c2ec51bb02204 55Mi images/dmx-web-1.5.0-b18.tar.gz false
downloadAndPush 146 container.repository.cloudera.com/cdp-private/cloudera/cloud/dp-cluster-service-private:1.0.5-b15 cloudera/cloud/dp-cluster-service-private:1.0.5-b15 sha256:1add28eb3c4c12283cbc9e5a1d35956a84039b674d9f87b1c7692daedb20afc6 487Mi images/dp-cluster-service-private-1.0.5-b15.tar.gz false
downloadAndPush 147 container.repository.cloudera.com/cdp-private/cloudera/cloud/dp-migrate-private:1.0.5-b15 cloudera/cloud/dp-migrate-private:1.0.5-b15 sha256:dcb34a8316ed2ef2b4140c4f460e588615653cccd43b57da0a8a628107cf14dc 444Mi images/dp-migrate-private-1.0.5-b15.tar.gz false
downloadAndPush 148 container.repository.cloudera.com/cdp-private/cloudera/cloud/dp-web-private:1.0.5-b15 cloudera/cloud/dp-web-private:1.0.5-b15 sha256:fed9a8e4fa6c6b3f2f5ab835de968b731c3613708be64656fc37154a860fa36f 331Mi images/dp-web-private-1.0.5-b15.tar.gz false
downloadAndPush 149 container.repository.cloudera.com/cdp-private/cloudera/cdp-gateway:2.1.0-b239 cloudera/cdp-gateway:2.1.0-b239 sha256:c60f190a212d970d4ae15079ef998e97b17b4a3f8acdefa9702238338bbfac99 238Mi images/cdp-gateway-2.1.0-b239.tar.gz false
downloadAndPush 150 container.repository.cloudera.com/cdp-private/cloudera/dwx:1.6.0-b58 cloudera/dwx:1.6.0-b58 sha256:c4ce709ec3d26f0f9bac0d142fe55cc5c565daf9f7e1c4e5307695700b8d682e 1Gi images/dwx-1.6.0-b58.tar.gz false
downloadAndPush 151 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/library/busybox:1.33.1 cloudera_thirdparty/library/busybox:1.33.1 sha256:d3cd072556c21c1f1940bd536675b97d7d419a2287d6bb3bd5044ea7466db788 1Mi images/busybox-1.33.1.tar.gz false
downloadAndPush 152 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/kubernetesui/dashboard:v2.4.0 cloudera_thirdparty/kubernetesui/dashboard:v2.4.0 sha256:72f07539ffb588d195e8697338c5e5d118e307e8c40ca612904dfb1f5066ebd4 211Mi images/dashboard-v2.4.0.tar.gz false
downloadAndPush 153 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/kube-state-metrics/kube-state-metrics:v2.2.0 cloudera_thirdparty/kube-state-metrics/kube-state-metrics:v2.2.0 sha256:8ceaed6e0b5dd0510ab5dae10886c6826d0ba54a4990e4f4c33ab009e630cfbd 36Mi images/kube-state-metrics-v2.2.0.tar.gz false
downloadAndPush 154 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/prometheus/node-exporter:v1.2.2 cloudera_thirdparty/prometheus/node-exporter:v1.2.2 sha256:0fafea14985942e880dd5b7df98f97f51a2ac25a2eb901a78e53e8b21cfb21c2 20Mi images/node-exporter-v1.2.2.tar.gz false
downloadAndPush 155 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/prometheus/prometheus:v2.34.0 cloudera_thirdparty/prometheus/prometheus:v2.34.0 sha256:e3cf894a63f5512315996b84076ab036e560b85bcd8331419493da8757be0d17 195Mi images/prometheus-v2.34.0.tar.gz false
downloadAndPush 156 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/prometheus/alertmanager:v0.22.2 cloudera_thirdparty/prometheus/alertmanager:v0.22.2 sha256:bed86c08a78add7d3fa3a25473e229c5aab6e8e26d33e0faef088514d79dad67 49Mi images/alertmanager-v0.22.2.tar.gz false
downloadAndPush 157 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/prometheus-operator/prometheus-config-reloader:v0.50.0 cloudera_thirdparty/prometheus-operator/prometheus-config-reloader:v0.50.0 sha256:972e89374460eca39d1d1018fc160fdc0ffcbfc43b32813e377ba9dd94d4880b 11Mi images/prometheus-config-reloader-v0.50.0.tar.gz false
downloadAndPush 158 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/prometheus-operator/prometheus-operator:v0.50.0 cloudera_thirdparty/prometheus-operator/prometheus-operator:v0.50.0 sha256:e8718944b25c5cc6d1517c8497881036810280ee67f1d5e46db59a094de2ae4d 45Mi images/prometheus-operator-v0.50.0.tar.gz false
downloadAndPush 159 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/ecs/ecs-tolerations-webhook:v5 cloudera_thirdparty/ecs/ecs-tolerations-webhook:v5 sha256:f4172e650cc806a930ff233d5fa4ab99e449ab7d2b88a1be3a96bfbd30fa8b9e 117Mi images/ecs-tolerations-webhook-v5.tar.gz false
downloadAndPush 160 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/hashicorp/vault:1.9.0 cloudera_thirdparty/hashicorp/vault:1.9.0 sha256:996ebb03026415698fac1785c57672eb40c0a6e7f8138233815046c3f3511e58 186Mi images/vault-1.9.0.tar.gz false
downloadAndPush 161 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/vault-exporter:2.2.0-ubi-minimal-8.4-208.cldr.1 cloudera_thirdparty/vault-exporter:2.2.0-ubi-minimal-8.4-208.cldr.1 sha256:dce8eb9d659a11aac0459c6316fdcf4f0620c45029f7736ba2203c54a1cbd236 112Mi images/vault-exporter-2.2.0-ubi-minimal-8.4-208.cldr.1.tar.gz false
downloadAndPush 162 container.repository.cloudera.com/cdp-private/cloudera/feng:2022.0.11.1-15 cloudera/feng:2022.0.11.1-15 sha256:fd7fd34c3858010f48b9c32aa46130ab2102ae2a6bc7e1ad172e8ba698d1cb54 2Gi images/feng-2022.0.11.1-15.tar.gz false
downloadAndPush 163 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/fluent-bit:v1.9.8 cloudera_thirdparty/fluent-bit:v1.9.8 sha256:e1a4b9b9084be25c2015018d93b39afaa752164cf31cb4889c0e437eb1e86d90 219Mi images/fluent-bit-v1.9.8.tar.gz false
downloadAndPush 164 container.repository.cloudera.com/cdp-private/cloudera/fluentd:1.6.0-b58 cloudera/fluentd:1.6.0-b58 sha256:65cd0c31ececa10b15f49c9db0dc3cf86c64901ba3df07aaf47d0caa4c9dbc62 871Mi images/fluentd-1.6.0-b58.tar.gz false
downloadAndPush 165 container.repository.cloudera.com/cdp-private/cloudera/hive:2022.0.11.1-15 cloudera/hive:2022.0.11.1-15 sha256:862876f596b523338fedb0be38b4b575c85a7e7ec03c8f6317bf84ccca581e58 2Gi images/hive-2022.0.11.1-15.tar.gz false
downloadAndPush 166 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/hashicorp/http-echo:0.2.3 cloudera_thirdparty/hashicorp/http-echo:0.2.3 sha256:a6838e9a6ff6ab3624720a7bd36152dda540ce3987714398003e14780e61478a 3Mi images/http-echo-0.2.3.tar.gz false
downloadAndPush 167 container.repository.cloudera.com/cdp-private/cloudera/hue:2022.0.11.1-15 cloudera/hue:2022.0.11.1-15 sha256:5404752bedd34c4a14d751827ec7607a22f1381e0222c30b476fa13be7e227a4 1Gi images/hue-2022.0.11.1-15.tar.gz false
downloadAndPush 168 container.repository.cloudera.com/cdp-private/cloudera/huelb:2022.0.11.1-15 cloudera/huelb:2022.0.11.1-15 sha256:00ef26a16e2dc2e2f478f16b87f8c68e9749260992a07d53f6c134de38f6c8bf 507Mi images/huelb-2022.0.11.1-15.tar.gz false
downloadAndPush 169 container.repository.cloudera.com/cdp-private/cloudera/hueqp:2022.0.11.1-15 cloudera/hueqp:2022.0.11.1-15 sha256:75080af36e32cc575285f8d908657053878fef475915ebef130681f6342ce1f1 827Mi images/hueqp-2022.0.11.1-15.tar.gz false
downloadAndPush 170 container.repository.cloudera.com/cdp-private/cloudera/impala-autoscaler:1.6.0-b58 cloudera/impala-autoscaler:1.6.0-b58 sha256:ec720091c960fccfb3177e321232bb2b838f1e8d1e3fa4157088bdb545026ae4 607Mi images/impala-autoscaler-1.6.0-b58.tar.gz false
downloadAndPush 171 container.repository.cloudera.com/cdp-private/cloudera/impala-proxy:1.6.0-b58 cloudera/impala-proxy:1.6.0-b58 sha256:3f8ec8c4ad145ef61a4f927479dccd3f0b66cd346f0e073ed2cb26e74bc07d6f 328Mi images/impala-proxy-1.6.0-b58.tar.gz false
downloadAndPush 172 container.repository.cloudera.com/cdp-private/cloudera/impalad_coord_exec:2022.0.11.1-15 cloudera/impalad_coord_exec:2022.0.11.1-15 sha256:3abb7a07c5baa8affd70051a67f006b74a004e63c6866bd027c81e72230a3dd9 908Mi images/impalad_coord_exec-2022.0.11.1-15.tar.gz false
downloadAndPush 173 container.repository.cloudera.com/cdp-private/cloudera/impalad_coordinator:2022.0.11.1-15 cloudera/impalad_coordinator:2022.0.11.1-15 sha256:c0b56839f10d79351c9200a538dab945794fef95edd3d5ed065c4ca1dfcf3c4f 908Mi images/impalad_coordinator-2022.0.11.1-15.tar.gz false
downloadAndPush 174 container.repository.cloudera.com/cdp-private/cloudera/impalad_executor:2022.0.11.1-15 cloudera/impalad_executor:2022.0.11.1-15 sha256:54d5e6c806a97b65da64b3766286d80de63b6e5800bb634a01b99619fee5e5a3 908Mi images/impalad_executor-2022.0.11.1-15.tar.gz false
downloadAndPush 175 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/vmware/kube-fluentd-operator:v1.16.7 cloudera_thirdparty/vmware/kube-fluentd-operator:v1.16.7 sha256:372a2b654bf5e64c10fb6f06c518379e7a380da9d6961d297c8b34a3d2217872 410Mi images/kube-fluentd-operator-v1.16.7.tar.gz false
downloadAndPush 176 container.repository.cloudera.com/cdp-private/cloudera/leader-elector:1.6.0-b58 cloudera/leader-elector:1.6.0-b58 sha256:b109431db3f028049c57adac4de49b3c87d000d09dd10c7155d558e5eea4d62a 276Mi images/leader-elector-1.6.0-b58.tar.gz false
downloadAndPush 177 container.repository.cloudera.com/cdp-private/cloudera/liftie:1.17.1-b39 cloudera/liftie:1.17.1-b39 sha256:513a5fe29d2a76150092965f28ed7e3b067caaef3ab7003ed9ebb235c7abbe55 514Mi images/liftie-1.17.1-b39.tar.gz false
downloadAndPush 178 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/rancher/local-path-provisioner:v0.0.23 cloudera_thirdparty/rancher/local-path-provisioner:v0.0.23 sha256:9621e18c3388039eda91c805c1b2ea190c8f2e0fa3a12ac4cee96ea138751585 35Mi images/local-path-provisioner-v0.0.23.tar.gz false
downloadAndPush 179 container.repository.cloudera.com/cdp-private/cloudera/logger-alert-receiver:1.5.0-b32 cloudera/logger-alert-receiver:1.5.0-b32 sha256:dc7a08b03ef850ae28f0ed6584dbc8966c7ee0069fed3d387f01510de75c40da 240Mi images/logger-alert-receiver-1.5.0-b32.tar.gz false
downloadAndPush 180 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/longhornio/longhorn-engine:v1.3.2 cloudera_thirdparty/longhornio/longhorn-engine:v1.3.2 sha256:8681890ac02c07bedfd2f17c336a4c9803c9539086d18638bba3efe28dfdcbb2 745Mi images/longhorn-engine-v1.3.2.tar.gz false
downloadAndPush 181 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/longhornio/longhorn-instance-manager:v1_20221003 cloudera_thirdparty/longhornio/longhorn-instance-manager:v1_20221003 sha256:36b11648e019a9dc0886101f557b2b2a98c69b3081c27571d9b5cf9da977a2f6 743Mi images/longhorn-instance-manager-v1_20221003.tar.gz false
downloadAndPush 182 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/longhornio/longhorn-manager:v1.3.2 cloudera_thirdparty/longhornio/longhorn-manager:v1.3.2 sha256:de93f80351954b18b95039c7f2e473319a0e086f6b33e0402fcff654ee52933b 272Mi images/longhorn-manager-v1.3.2.tar.gz false
downloadAndPush 183 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/longhornio/longhorn-share-manager:v1_20221003 cloudera_thirdparty/longhornio/longhorn-share-manager:v1_20221003 sha256:05ac49082dc8307cf0a994f08d4490a6bcaeba739e49c746bf18f159edf01516 200Mi images/longhorn-share-manager-v1_20221003.tar.gz false
downloadAndPush 184 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/longhornio/longhorn-ui:v1.3.2 cloudera_thirdparty/longhornio/longhorn-ui:v1.3.2 sha256:986423ced5a53f8f09102b245644012d7475c800043ebb0ec445f2993d7b04cf 190Mi images/longhorn-ui-v1.3.2.tar.gz false
downloadAndPush 185 container.repository.cloudera.com/cdp-private/cloudera/metrics-server-exporter:1.5.0-b32 cloudera/metrics-server-exporter:1.5.0-b32 sha256:01219e94f48556e426bc8fc592dbfa5661c5435d3c3086d35ba14698a1500a6f 240Mi images/metrics-server-exporter-1.5.0-b32.tar.gz false
downloadAndPush 186 container.repository.cloudera.com/cdp-private/cloudera/mlx-control-plane-app:1.35.0-b110 cloudera/mlx-control-plane-app:1.35.0-b110 sha256:e2620f32fc6507867c8899b7c4c0a1a518ebedf241899a6ae80d5ff8fdccfdbb 411Mi images/mlx-control-plane-app-1.35.0-b110.tar.gz false
downloadAndPush 187 container.repository.cloudera.com/cdp-private/cloudera/mlx-control-plane-app-cadence-worker:1.35.0-b110 cloudera/mlx-control-plane-app-cadence-worker:1.35.0-b110 sha256:e33325d7304995f7d792474fd03e15b03bb52c594ccc9727e0c0d1001f2a8b28 361Mi images/mlx-control-plane-app-cadence-worker-1.35.0-b110.tar.gz false
downloadAndPush 188 container.repository.cloudera.com/cdp-private/cloudera/mlx-control-plane-app-cdsw-migrator:1.35.0-b110 cloudera/mlx-control-plane-app-cdsw-migrator:1.35.0-b110 sha256:83bb3d8f0376ae2c5f93b5f3d36015ec2edc6786841d04b1e644c1a9419f58d5 388Mi images/mlx-control-plane-app-cdsw-migrator-1.35.0-b110.tar.gz false
downloadAndPush 189 container.repository.cloudera.com/cdp-private/cloudera/mlx-control-plane-app-health-poller:1.35.0-b110 cloudera/mlx-control-plane-app-health-poller:1.35.0-b110 sha256:f1c2c06e377953fd0d8c6c75f62afb95b39fd4b58c47746ab90d3a92e0cead30 215Mi images/mlx-control-plane-app-health-poller-1.35.0-b110.tar.gz false
downloadAndPush 190 container.repository.cloudera.com/cdp-private/cloudera/cdsw/third-party/model-registry:1.0.1-b863 cloudera/cdsw/third-party/model-registry:1.0.1-b863 sha256:e43e6bf8625704ef8fbcedb0614d3426da88137a91a33c9318ba5a16fedc28f3 140Mi images/model-registry-1.0.1-b863.tar.gz false
downloadAndPush 191 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/ubi-alertmanager:0.20.0-ubi-minimal-8.4-208.cldr.2 cloudera_thirdparty/ubi-alertmanager:0.20.0-ubi-minimal-8.4-208.cldr.2 sha256:6a46226fd1121aaba427084875f7b496543afc30f3f59ce9290df025952ce9cb 144Mi images/ubi-alertmanager-0.20.0-ubi-minimal-8.4-208.cldr.2.tar.gz false
downloadAndPush 192 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/fluentd:v1.15.2-cldr-2 cloudera_thirdparty/fluentd:v1.15.2-cldr-2 sha256:f6d631637177b29e0574b02e4704fc29e8353c4a6cc27c3df2131623a36f421c 302Mi images/fluentd-v1.15.2-cldr-2.tar.gz false
downloadAndPush 193 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/ubi-grafana:6.7.4-ubi-8.4-206.1626828523.cldr.1 cloudera_thirdparty/ubi-grafana:6.7.4-ubi-8.4-206.1626828523.cldr.1 sha256:e09f0c679a6598755e0bc6d26f91c70f9d40f91bbea2228c86c17d5aedd11a92 680Mi images/ubi-grafana-6.7.4-ubi-8.4-206.1626828523.cldr.1.tar.gz false
downloadAndPush 194 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/ubi-k8s-sidecar:1.12.2-python-38-1-63.1626843762.cldr.1 cloudera_thirdparty/ubi-k8s-sidecar:1.12.2-python-38-1-63.1626843762.cldr.1 sha256:9dd6e314c924106df3a8c10ea1795c3f3255935114d2e93cb2108a43c2a2c0d3 867Mi images/ubi-k8s-sidecar-1.12.2-python-38-1-63.1626843762.cldr.1.tar.gz false
downloadAndPush 195 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/ubi-kube-state-metrics:2.2.3-ubi-minimal-8.4-208.cldr.1 cloudera_thirdparty/ubi-kube-state-metrics:2.2.3-ubi-minimal-8.4-208.cldr.1 sha256:366c115f265ed85a06b0431a0c536a166f2e0dfb9fb9f203cb897c306b24bef8 132Mi images/ubi-kube-state-metrics-2.2.3-ubi-minimal-8.4-208.cldr.1.tar.gz false
downloadAndPush 196 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/ubi-node_exporter:1.2.2-ubi-minimal-8.4-208.cldr.3 cloudera_thirdparty/ubi-node_exporter:1.2.2-ubi-minimal-8.4-208.cldr.3 sha256:8541c75576ea3ed4c1139e2e14ecb861ba55c23701fe55c9b5bd15c25689f772 115Mi images/ubi-node_exporter-1.2.2-ubi-minimal-8.4-208.cldr.3.tar.gz false
downloadAndPush 197 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/ubi-prometheus:2.30.3-ubi-minimal-8.4-208.cldr.3 cloudera_thirdparty/ubi-prometheus:2.30.3-ubi-minimal-8.4-208.cldr.3 sha256:cbf7c5ddc21ff970275485b2c3d6a00d9af1f02af473e5a874258cd7a3537215 279Mi images/ubi-prometheus-2.30.3-ubi-minimal-8.4-208.cldr.3.tar.gz false
downloadAndPush 198 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/ubi-configmap-reload:0.5.0-ubi-minimal-8.4-208.cldr.5 cloudera_thirdparty/ubi-configmap-reload:0.5.0-ubi-minimal-8.4-208.cldr.5 sha256:82fb1ce3f2f901dcfa670b6d07d0436e673c43a137fb99b7b7e34a1a6ea70877 106Mi images/ubi-configmap-reload-0.5.0-ubi-minimal-8.4-208.cldr.5.tar.gz false
downloadAndPush 199 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/ubi-pushgateway:1.4.2-ubi-minimal-8.4-208.cldr.3 cloudera_thirdparty/ubi-pushgateway:1.4.2-ubi-minimal-8.4-208.cldr.3 sha256:d0cc47d82835d708cf7231b3013bd6c61da3c6b86e5b50d00f23057202191cca 114Mi images/ubi-pushgateway-1.4.2-ubi-minimal-8.4-208.cldr.3.tar.gz false
downloadAndPush 200 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/ubi-snmp_notifier:1.2.0-ubi-minimal-8.4-208.cldr.1 cloudera_thirdparty/ubi-snmp_notifier:1.2.0-ubi-minimal-8.4-208.cldr.1 sha256:feb88051658247474e60cae478d0ccc95539969573d50359aa0bab1b4d34e7f0 109Mi images/ubi-snmp_notifier-1.2.0-ubi-minimal-8.4-208.cldr.1.tar.gz false
downloadAndPush 201 container.repository.cloudera.com/cdp-private/cloudera/monitoring-app:1.5.0-b32 cloudera/monitoring-app:1.5.0-b32 sha256:5fe28b71aa0016242937df10a73539a44fc924226f1b1b8f3354ce6bd396b042 671Mi images/monitoring-app-1.5.0-b32.tar.gz false
downloadAndPush 202 container.repository.cloudera.com/cdp-private/cloudera/monitoring-controller-manager:1.5.0-b32 cloudera/monitoring-controller-manager:1.5.0-b32 sha256:160040dc6c00ddd949f97c8e0d3beaf46b946c845a511ebf4b6f80484dfa3ec2 215Mi images/monitoring-controller-manager-1.5.0-b32.tar.gz false
downloadAndPush 203 container.repository.cloudera.com/cdp-private/cloudera/multilog-init:1.5.0-b32 cloudera/multilog-init:1.5.0-b32 sha256:af154b3dcb38b89cc9c67918284e993fd4332808de0c95d07ce23592bcc536bc 116Mi images/multilog-init-1.5.0-b32.tar.gz false
downloadAndPush 204 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/kubernetes_incubator/nfs-provisioner:v2.3.0 cloudera_thirdparty/kubernetes_incubator/nfs-provisioner:v2.3.0 sha256:3830c0da69e19581c9af587be04390d24bc7e01642abc96e7e49a2b61eea29c8 275Mi images/nfs-provisioner-v2.3.0.tar.gz false
downloadAndPush 205 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/nvidia/k8s-device-plugin:v0.9.0 cloudera_thirdparty/nvidia/k8s-device-plugin:v0.9.0 sha256:37b8c3899b153afc2c7e65e1939330654276560b8b5f6dffdfd466bd8b4f7ef8 181Mi images/k8s-device-plugin-v0.9.0.tar.gz false
downloadAndPush 206 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/pause:3.5 cloudera_thirdparty/pause:3.5 sha256:ed210e3e4a5bae1237f1bb44d72a05a2f1e5c6bfe7a7e73da179e2534269c459 666Ki images/pause-3.5.tar.gz false
downloadAndPush 207 container.repository.cloudera.com/cdp-private/cloudera/platform-agent-proxy:1.5.0-b4 cloudera/platform-agent-proxy:1.5.0-b4 sha256:e21a44a964965277a0c78aef2dba1859fc8dd11b929be898e99f549d824c9140 114Mi images/platform-agent-proxy-1.5.0-b4.tar.gz false
downloadAndPush 208 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/postgres:11.16-alpine3.16 cloudera_thirdparty/postgres:11.16-alpine3.16 sha256:ca10fe3b90936f02e3818fe8cee1ca27ebfd3323e4b12c74d59aa2eb19ff6dce 199Mi images/postgres-11.16-alpine3.16.tar.gz false
downloadAndPush 209 container.repository.cloudera.com/cdp-private/cloudera/resource-pool-manager:0.12.0-b19 cloudera/resource-pool-manager:0.12.0-b19 sha256:f70f136acdf01f318daa5e7e6ceb6fe1dd368075621ef3fd92a39fc89fcbdadf 131Mi images/resource-pool-manager-0.12.0-b19.tar.gz false
downloadAndPush 210 container.repository.cloudera.com/cdp-private/cloudera/service-discovery:1.6.0-b58 cloudera/service-discovery:1.6.0-b58 sha256:ae9f02adf8e602f9c3ef8d2fdc88d50897156c670f88fe91ea7285c3bcf423c8 296Mi images/service-discovery-1.6.0-b58.tar.gz false
downloadAndPush 211 container.repository.cloudera.com/cdp-private/cloudera/statestored:2022.0.11.1-15 cloudera/statestored:2022.0.11.1-15 sha256:2d7c387d55d5cb67f8eda7a680690232754de80b8c4c8fad03e9ff51142ed53f 472Mi images/statestored-2022.0.11.1-15.tar.gz false
downloadAndPush 212 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/fluentd:v1.15.3-cldr-2 cloudera_thirdparty/fluentd:v1.15.3-cldr-2 sha256:90a8f76cdcbae5f0a92060b74c555ca1423dc2ec25b16b5f9fe985c3cefe8b1e 306Mi images/fluentd-v1.15.3-cldr-2.tar.gz false
downloadAndPush 213 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-backupjob:1.5.0-b767 cloudera/thunderhead-backupjob:1.5.0-b767 sha256:ce4f51948ecbc4b7b03528dd42f1a0e6acb720e0d2664ec3b4a8d359e4de83f0 561Mi images/thunderhead-backupjob-1.5.0-b767.tar.gz false
downloadAndPush 214 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-cdp-private-authentication-console:1.5.0-b767 cloudera/thunderhead-cdp-private-authentication-console:1.5.0-b767 sha256:b0ee08cddc83e6b40424ccf60791b2d978c374558679093bf1a5cc2e3c82e6b5 446Mi images/thunderhead-cdp-private-authentication-console-1.5.0-b767.tar.gz false
downloadAndPush 215 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-cdp-private-commonconsole:1.5.0-b767 cloudera/thunderhead-cdp-private-commonconsole:1.5.0-b767 sha256:d7261bb4d32f776dda2d62b1e9c6ee041a12a2c0ffe4c8459c5637fafd0a0134 446Mi images/thunderhead-cdp-private-commonconsole-1.5.0-b767.tar.gz false
downloadAndPush 216 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-cdp-private-environments-console:1.5.0-b767 cloudera/thunderhead-cdp-private-environments-console:1.5.0-b767 sha256:77ab16f632ff8d8504abc01b511653a79d7144c08eba5db81ec6a3036f5644e9 452Mi images/thunderhead-cdp-private-environments-console-1.5.0-b767.tar.gz false
downloadAndPush 217 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-compute-api:1.5.0-b767 cloudera/thunderhead-compute-api:1.5.0-b767 sha256:c179ec6ba610918d60057f8e03dea9aee50a334471e43e9cf9a2e04aa6995422 538Mi images/thunderhead-compute-api-1.5.0-b767.tar.gz false
downloadAndPush 218 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-configmap-autoupdater:1.5.0-b767 cloudera/thunderhead-configmap-autoupdater:1.5.0-b767 sha256:695c77cd196d01449246ccf396d50c7b680ce936cc40a6435d86a2d63d5d8b4f 50Mi images/thunderhead-configmap-autoupdater-1.5.0-b767.tar.gz false
downloadAndPush 219 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-configtemplate:1.5.0-b767 cloudera/thunderhead-configtemplate:1.5.0-b767 sha256:afb19cc38d1215eb209721a8d32a40935a110dfcf7fcdb9ecf4ee6d522b1b7e2 552Mi images/thunderhead-configtemplate-1.5.0-b767.tar.gz false
downloadAndPush 220 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-consoleauthenticationcdp:1.5.0-b767 cloudera/thunderhead-consoleauthenticationcdp:1.5.0-b767 sha256:490989a5fd06746ea9f34b1432348cbc42fe04f75cf95dda78b1d6a017a0a9a2 532Mi images/thunderhead-consoleauthenticationcdp-1.5.0-b767.tar.gz false
downloadAndPush 221 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-de-api:1.5.0-b767 cloudera/thunderhead-de-api:1.5.0-b767 sha256:6d5123b5b4ce091677e35a526abfb1050f5884f6e21ae625315c4730ed30124d 532Mi images/thunderhead-de-api-1.5.0-b767.tar.gz false
downloadAndPush 222 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-deletebackupjob:1.5.0-b767 cloudera/thunderhead-deletebackupjob:1.5.0-b767 sha256:cf1545490e71b53277160ecd1652c74ac1f7dda85536a96a92adf9da34d958f8 561Mi images/thunderhead-deletebackupjob-1.5.0-b767.tar.gz false
downloadAndPush 223 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-diagnostics-api:1.5.0-b767 cloudera/thunderhead-diagnostics-api:1.5.0-b767 sha256:394e8150c8445e99d07c85d9565e288dc9857b92aa56e0539dbd358428b488b6 570Mi images/thunderhead-diagnostics-api-1.5.0-b767.tar.gz false
downloadAndPush 224 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-drscp-api:1.5.0-b767 cloudera/thunderhead-drscp-api:1.5.0-b767 sha256:0445cafac0636b862f17dd757f78dfed55008f0fed6503e22cab4b392457a7aa 555Mi images/thunderhead-drscp-api-1.5.0-b767.tar.gz false
downloadAndPush 225 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-drsprovider:1.5.0-b767 cloudera/thunderhead-drsprovider:1.5.0-b767 sha256:1c50e143dfbfd9d63a0d2f135fceaed131fa043fa799d1b5cc3b5bc966f04c16 561Mi images/thunderhead-drsprovider-1.5.0-b767.tar.gz false
downloadAndPush 226 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-dw-api:1.5.0-b767 cloudera/thunderhead-dw-api:1.5.0-b767 sha256:ee6acfd2d9313b44eea74022bedab3fd17e8097959f82bace89ef93169695a3a 533Mi images/thunderhead-dw-api-1.5.0-b767.tar.gz false
downloadAndPush 227 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-environment:1.5.0-b767 cloudera/thunderhead-environment:1.5.0-b767 sha256:2628a1991069dfa57ca5897453f947e1097de6336ba2c38f7eac1b490825ad83 577Mi images/thunderhead-environment-1.5.0-b767.tar.gz false
downloadAndPush 228 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-environments2-api:1.5.0-b767 cloudera/thunderhead-environments2-api:1.5.0-b767 sha256:adec2363e38058069289b390cdeda0ddc98b0f194fece4ab9afa70fe846b8227 568Mi images/thunderhead-environments2-api-1.5.0-b767.tar.gz false
downloadAndPush 229 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-iam-api:1.5.0-b767 cloudera/thunderhead-iam-api:1.5.0-b767 sha256:4657957e7d11317922c4ebbfdd5bdb610c222009cb6122a38d30103402ecb020 538Mi images/thunderhead-iam-api-1.5.0-b767.tar.gz false
downloadAndPush 230 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-iam-console:1.5.0-b767 cloudera/thunderhead-iam-console:1.5.0-b767 sha256:b7d5f9ccaa241f038ff0e62111289a2fb242fc77b7249848d17f7b1bc0af4015 450Mi images/thunderhead-iam-console-1.5.0-b767.tar.gz false
downloadAndPush 231 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-java-init-container-11:1.5.0-b767 cloudera/thunderhead-java-init-container-11:1.5.0-b767 sha256:d2396c18be9dfd8c7a4e9fd21811d7489ca24be50f88731afd182aae79e600dd 440Mi images/thunderhead-java-init-container-11-1.5.0-b767.tar.gz false
downloadAndPush 232 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-kerberosmgmt-api:1.5.0-b767 cloudera/thunderhead-kerberosmgmt-api:1.5.0-b767 sha256:1eafced28b46c3859fc7bf392ad2916ade39b76cc61d508a36a4350356db1b4f 534Mi images/thunderhead-kerberosmgmt-api-1.5.0-b767.tar.gz false
downloadAndPush 233 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-ml-api:1.5.0-b767 cloudera/thunderhead-ml-api:1.5.0-b767 sha256:0308db7e2912d96755c91ad51c1cac798104574ed85c468af164d5b66307a96e 531Mi images/thunderhead-ml-api-1.5.0-b767.tar.gz false
downloadAndPush 234 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-mlopsgovernance:1.5.0-b767 cloudera/thunderhead-mlopsgovernance:1.5.0-b767 sha256:decb821ac51f9366c5a38048af650dd0aa17e2b1272edf445ec896526b83bcb6 570Mi images/thunderhead-mlopsgovernance-1.5.0-b767.tar.gz false
downloadAndPush 235 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-pre-install-validation:1.5.0-b767 cloudera/thunderhead-pre-install-validation:1.5.0-b767 sha256:54aa83aac770eabc12f50bff313715b94afc4a2a63179feffc63906a1202029f 47Mi images/thunderhead-pre-install-validation-1.5.0-b767.tar.gz false
downloadAndPush 236 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-resource-management-console:1.5.0-b767 cloudera/thunderhead-resource-management-console:1.5.0-b767 sha256:af243171c36267f0d3feebff879fea1549dfe7fa04d104a3087b455eefaa85d9 448Mi images/thunderhead-resource-management-console-1.5.0-b767.tar.gz false
downloadAndPush 237 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-restorejob:1.5.0-b767 cloudera/thunderhead-restorejob:1.5.0-b767 sha256:844f01bf4fd85309d383e403fe942db4a113d7375a6cbb9495783ae82ffc306f 561Mi images/thunderhead-restorejob-1.5.0-b767.tar.gz false
downloadAndPush 238 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-sdx2-api:1.5.0-b767 cloudera/thunderhead-sdx2-api:1.5.0-b767 sha256:358fb82df54f23d05942f237ef922564a4fab98a6ac30c30775c75eb2b2525ba 531Mi images/thunderhead-sdx2-api-1.5.0-b767.tar.gz false
downloadAndPush 239 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-servicediscoverysimple:1.5.0-b767 cloudera/thunderhead-servicediscoverysimple:1.5.0-b767 sha256:96c1408e3902c65997a6a6e532af0e62c83c2491fe812a221f0d83fe12743408 533Mi images/thunderhead-servicediscoverysimple-1.5.0-b767.tar.gz false
downloadAndPush 240 container.repository.cloudera.com/cdp-private/cloudera/thunderhead-usermanagement-private:1.5.0-b767 cloudera/thunderhead-usermanagement-private:1.5.0-b767 sha256:ec6ec786031ceb7f3d1a1ef2d90a1b4e1989de527f04e950bf452f9ac125a972 546Mi images/thunderhead-usermanagement-private-1.5.0-b767.tar.gz false
downloadAndPush 241 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/ubi-traefik:v2.9.1-8.5-230 cloudera_thirdparty/ubi-traefik:v2.9.1-8.5-230 sha256:fdf43e672eab4fc612a99d7c0e009fa1ed16671ac082569b13bf599909965566 212Mi images/ubi-traefik-v2.9.1-8.5-230.tar.gz false
downloadAndPush 242 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/hashicorp/vault:1.9.0 cloudera_thirdparty/hashicorp/vault:1.9.0 sha256:996ebb03026415698fac1785c57672eb40c0a6e7f8138233815046c3f3511e58 186Mi images/vault-1.9.0.tar.gz false
downloadAndPush 243 container.repository.cloudera.com/cdp-private/cloudera/cdsw/third-party/pod-evaluator/webhook:1.0.1.0-52 cloudera/cdsw/third-party/pod-evaluator/webhook:1.0.1.0-52 sha256:f1a65b1eace5d3c9d7362a9134070a99893e213807f673f6c4f9cdd42c4a115e 39Mi images/webhook-1.0.1.0-52.tar.gz false
downloadAndPush 244 container.repository.cloudera.com/cdp-private/cloudera_thirdparty/ingress-nginx/kube-webhook-certgen:v1.1.1 cloudera_thirdparty/ingress-nginx/kube-webhook-certgen:v1.1.1 sha256:c41e9fcadf5a291120de706b7dfa1af598b9f2ed5138b6dcb9f79a68aad0ef4c 45Mi images/kube-webhook-certgen-v1.1.1.tar.gz false
downloadAndPush 245 container.repository.cloudera.com/cdp-private/cloudera/yunikorn-admission:1.1.0-b29 cloudera/yunikorn-admission:1.1.0-b29 sha256:0c41d9cd671fa0973fa60aa15173b774cf05d53d7edb0c0a1b4a368c48bf455a 137Mi images/yunikorn-admission-1.1.0-b29.tar.gz false
downloadAndPush 246 container.repository.cloudera.com/cdp-private/cloudera/yunikorn-scheduler-plugin:1.1.0-b29 cloudera/yunikorn-scheduler-plugin:1.1.0-b29 sha256:7d670c448df1873669dff175c5c6ff975bc82190dec6646780e44b63d1f59418 159Mi images/yunikorn-scheduler-plugin-1.1.0-b29.tar.gz false
downloadAndPush 247 container.repository.cloudera.com/cdp-private/cloudera/yunikorn-web:1.1.0-b29 cloudera/yunikorn-web:1.1.0-b29 sha256:e43501369f9a1eaca48eaaa74e96026a9617cdbf926d746df3b609baf2ee4544 211Mi images/yunikorn-web-1.1.0-b29.tar.gz false
downloadPackageOnly c2ee180efce670e22f8504ce458a005b 1GB images/cdv-runtimes-1.5.0-b448.tar.gz

markAsDownloaded cloudera/cdv/runtimedataviz:7.0.3-b57 images/cdv-runtimes-1.5.0-b448.tar.gz
downloadPackageOnly 213e6b5ab140490254d8521e42cf5501 3GB images/cml-runtimes-cuda-1.5.0-b448.tar.gz






markAsDownloaded cloudera/cdsw/ml-runtime-jupyterlab-python3.7-cuda:2022.11.1-b2 images/cml-runtimes-cuda-1.5.0-b448.tar.gz
markAsDownloaded cloudera/cdsw/ml-runtime-jupyterlab-python3.8-cuda:2022.11.1-b2 images/cml-runtimes-cuda-1.5.0-b448.tar.gz
markAsDownloaded cloudera/cdsw/ml-runtime-jupyterlab-python3.9-cuda:2022.11.1-b2 images/cml-runtimes-cuda-1.5.0-b448.tar.gz
markAsDownloaded cloudera/cdsw/ml-runtime-workbench-python3.7-cuda:2022.11.1-b2 images/cml-runtimes-cuda-1.5.0-b448.tar.gz
markAsDownloaded cloudera/cdsw/ml-runtime-workbench-python3.8-cuda:2022.11.1-b2 images/cml-runtimes-cuda-1.5.0-b448.tar.gz
markAsDownloaded cloudera/cdsw/ml-runtime-workbench-python3.9-cuda:2022.11.1-b2 images/cml-runtimes-cuda-1.5.0-b448.tar.gz
downloadPackageOnly d8c76aac377033508ec37c43c8cbca48 2GB images/cml-runtimes-standard-1.5.0-b448.tar.gz
















markAsDownloaded cloudera/cdsw/ml-runtime-jupyterlab-python3.7-standard:2022.11.1-b2 images/cml-runtimes-standard-1.5.0-b448.tar.gz
markAsDownloaded cloudera/cdsw/ml-runtime-jupyterlab-python3.8-standard:2022.11.1-b2 images/cml-runtimes-standard-1.5.0-b448.tar.gz
markAsDownloaded cloudera/cdsw/ml-runtime-jupyterlab-python3.9-standard:2022.11.1-b2 images/cml-runtimes-standard-1.5.0-b448.tar.gz
markAsDownloaded cloudera/cdsw/ml-runtime-pbj-workbench-python3.7-standard:2022.11.1-b2 images/cml-runtimes-standard-1.5.0-b448.tar.gz
markAsDownloaded cloudera/cdsw/ml-runtime-pbj-workbench-python3.8-standard:2022.11.1-b2 images/cml-runtimes-standard-1.5.0-b448.tar.gz
markAsDownloaded cloudera/cdsw/ml-runtime-pbj-workbench-python3.9-standard:2022.11.1-b2 images/cml-runtimes-standard-1.5.0-b448.tar.gz
markAsDownloaded cloudera/cdsw/ml-runtime-pbj-workbench-r3.6-standard:2022.11.1-b2 images/cml-runtimes-standard-1.5.0-b448.tar.gz
markAsDownloaded cloudera/cdsw/ml-runtime-pbj-workbench-r4.0-standard:2022.11.1-b2 images/cml-runtimes-standard-1.5.0-b448.tar.gz
markAsDownloaded cloudera/cdsw/ml-runtime-pbj-workbench-r4.1-standard:2022.11.1-b2 images/cml-runtimes-standard-1.5.0-b448.tar.gz
markAsDownloaded cloudera/cdsw/ml-runtime-workbench-python3.7-standard:2022.11.1-b2 images/cml-runtimes-standard-1.5.0-b448.tar.gz
markAsDownloaded cloudera/cdsw/ml-runtime-workbench-python3.8-standard:2022.11.1-b2 images/cml-runtimes-standard-1.5.0-b448.tar.gz
markAsDownloaded cloudera/cdsw/ml-runtime-workbench-python3.9-standard:2022.11.1-b2 images/cml-runtimes-standard-1.5.0-b448.tar.gz
markAsDownloaded cloudera/cdsw/ml-runtime-workbench-r3.6-standard:2022.11.1-b2 images/cml-runtimes-standard-1.5.0-b448.tar.gz
markAsDownloaded cloudera/cdsw/ml-runtime-workbench-r4.0-standard:2022.11.1-b2 images/cml-runtimes-standard-1.5.0-b448.tar.gz
markAsDownloaded cloudera/cdsw/ml-runtime-workbench-r4.1-standard:2022.11.1-b2 images/cml-runtimes-standard-1.5.0-b448.tar.gz
markAsDownloaded cloudera/cdsw/ml-runtime-workbench-scala2.11-standard:2022.11.1-b2 images/cml-runtimes-standard-1.5.0-b448.tar.gz
dockerPushOnly 248 container.repository.cloudera.com/cdp-private/cloudera/cdsw/ml-runtime-jupyterlab-python3.7-cuda:2022.11.1-b2 cloudera/cdsw/ml-runtime-jupyterlab-python3.7-cuda:2022.11.1-b2 sha256:fb5042594f384bc90be0c2b6f4ac8ba98e5a51ed0f9e8f0af393a17ef6d94f17 5Gi  true
dockerPushOnly 249 container.repository.cloudera.com/cdp-private/cloudera/cdsw/ml-runtime-jupyterlab-python3.7-standard:2022.11.1-b2 cloudera/cdsw/ml-runtime-jupyterlab-python3.7-standard:2022.11.1-b2 sha256:b62dcb78cd46ade56a0e07e2f1bb4dff2259f20a9d8c140e0bbdf75057df9984 1Gi  true
dockerPushOnly 250 container.repository.cloudera.com/cdp-private/cloudera/cdsw/ml-runtime-jupyterlab-python3.8-cuda:2022.11.1-b2 cloudera/cdsw/ml-runtime-jupyterlab-python3.8-cuda:2022.11.1-b2 sha256:6f0c2fd72d1c9e961186980b2514426e2c370a265ae8a86c6f67355c82d06364 5Gi  true
dockerPushOnly 251 container.repository.cloudera.com/cdp-private/cloudera/cdsw/ml-runtime-jupyterlab-python3.8-standard:2022.11.1-b2 cloudera/cdsw/ml-runtime-jupyterlab-python3.8-standard:2022.11.1-b2 sha256:d2befd46c7fe0534f2e8eb962e3869a30de32f9d288c60c5e2f12ac7ffbaaf13 1Gi  true
dockerPushOnly 252 container.repository.cloudera.com/cdp-private/cloudera/cdsw/ml-runtime-jupyterlab-python3.9-cuda:2022.11.1-b2 cloudera/cdsw/ml-runtime-jupyterlab-python3.9-cuda:2022.11.1-b2 sha256:a524041a0bb3e5856733061afff0aac0f799fd73c4319616962c4016465f7aa6 5Gi  true
dockerPushOnly 253 container.repository.cloudera.com/cdp-private/cloudera/cdsw/ml-runtime-jupyterlab-python3.9-standard:2022.11.1-b2 cloudera/cdsw/ml-runtime-jupyterlab-python3.9-standard:2022.11.1-b2 sha256:1fc825025d624ee6b17232c48740cbe63d7f4d5d82587b69789c5820a72177e7 1Gi  true
dockerPushOnly 254 container.repository.cloudera.com/cdp-private/cloudera/cdsw/ml-runtime-pbj-workbench-python3.7-standard:2022.11.1-b2 cloudera/cdsw/ml-runtime-pbj-workbench-python3.7-standard:2022.11.1-b2 sha256:11420c0d10dacabe4952b85a9526c7c5e39747ce404e45698860730310d92dff 1Gi  true
dockerPushOnly 255 container.repository.cloudera.com/cdp-private/cloudera/cdsw/ml-runtime-pbj-workbench-python3.8-standard:2022.11.1-b2 cloudera/cdsw/ml-runtime-pbj-workbench-python3.8-standard:2022.11.1-b2 sha256:d9b6c929f541ae8f1365ada9d6d11b49979f08a081269bf511f20f3ea9415290 1Gi  true
dockerPushOnly 256 container.repository.cloudera.com/cdp-private/cloudera/cdsw/ml-runtime-pbj-workbench-python3.9-standard:2022.11.1-b2 cloudera/cdsw/ml-runtime-pbj-workbench-python3.9-standard:2022.11.1-b2 sha256:0f0000ce95df8c7dced830b16b5e5278e348b01002acf0c201afb5ad83d77109 1Gi  true
dockerPushOnly 257 container.repository.cloudera.com/cdp-private/cloudera/cdsw/ml-runtime-pbj-workbench-r3.6-standard:2022.11.1-b2 cloudera/cdsw/ml-runtime-pbj-workbench-r3.6-standard:2022.11.1-b2 sha256:689f649cba6995703db8c16e330c008dcdf04e2a572fcf754e11fee34339e8ac 1Gi  true
dockerPushOnly 258 container.repository.cloudera.com/cdp-private/cloudera/cdsw/ml-runtime-pbj-workbench-r4.0-standard:2022.11.1-b2 cloudera/cdsw/ml-runtime-pbj-workbench-r4.0-standard:2022.11.1-b2 sha256:b6d9b8447dd755a8012af32451c860598971d1ea10c08b95bd2bb80edc65cdc7 1Gi  true
dockerPushOnly 259 container.repository.cloudera.com/cdp-private/cloudera/cdsw/ml-runtime-pbj-workbench-r4.1-standard:2022.11.1-b2 cloudera/cdsw/ml-runtime-pbj-workbench-r4.1-standard:2022.11.1-b2 sha256:d8c32cf5a78f5889dfa7d387f1ec9187e0050d0a8ef8e69d9a85e83aa9b79823 1Gi  true
dockerPushOnly 260 container.repository.cloudera.com/cdp-private/cloudera/cdsw/ml-runtime-workbench-python3.7-cuda:2022.11.1-b2 cloudera/cdsw/ml-runtime-workbench-python3.7-cuda:2022.11.1-b2 sha256:1df52f3158d4160075b8272150996f7d66c4eb667aab50b5228640f9b818cf63 5Gi  true
dockerPushOnly 261 container.repository.cloudera.com/cdp-private/cloudera/cdsw/ml-runtime-workbench-python3.7-standard:2022.11.1-b2 cloudera/cdsw/ml-runtime-workbench-python3.7-standard:2022.11.1-b2 sha256:98c1bc75a2e981b31f49c94623ca499a1a815150b1d00e00cc4c63f991e51dd1 1Gi  true
dockerPushOnly 262 container.repository.cloudera.com/cdp-private/cloudera/cdsw/ml-runtime-workbench-python3.8-cuda:2022.11.1-b2 cloudera/cdsw/ml-runtime-workbench-python3.8-cuda:2022.11.1-b2 sha256:b32310be0d1755557ad61fe463a6f5d1872a1d525321097422747b89ae5ffe6e 5Gi  true
dockerPushOnly 263 container.repository.cloudera.com/cdp-private/cloudera/cdsw/ml-runtime-workbench-python3.8-standard:2022.11.1-b2 cloudera/cdsw/ml-runtime-workbench-python3.8-standard:2022.11.1-b2 sha256:7245500003b20e0e095dc43785645a1c314a790217315f12274aa57612387b04 1Gi  true
dockerPushOnly 264 container.repository.cloudera.com/cdp-private/cloudera/cdsw/ml-runtime-workbench-python3.9-cuda:2022.11.1-b2 cloudera/cdsw/ml-runtime-workbench-python3.9-cuda:2022.11.1-b2 sha256:8362ab5ff2f1c5ba9831ea3255a058376671adbb8215615e1a0466dfebad8628 5Gi  true
dockerPushOnly 265 container.repository.cloudera.com/cdp-private/cloudera/cdsw/ml-runtime-workbench-python3.9-standard:2022.11.1-b2 cloudera/cdsw/ml-runtime-workbench-python3.9-standard:2022.11.1-b2 sha256:65975cc2747eb329b5c148733652dc42a7a104182f72123fe16d8162f9b1ae0e 1Gi  true
dockerPushOnly 266 container.repository.cloudera.com/cdp-private/cloudera/cdsw/ml-runtime-workbench-r3.6-standard:2022.11.1-b2 cloudera/cdsw/ml-runtime-workbench-r3.6-standard:2022.11.1-b2 sha256:120e0a4e0ff980e15ed3ed7066f5b967d3ee8ab19f995c44ec4e0c7d18af27c1 1Gi  true
dockerPushOnly 267 container.repository.cloudera.com/cdp-private/cloudera/cdsw/ml-runtime-workbench-r4.0-standard:2022.11.1-b2 cloudera/cdsw/ml-runtime-workbench-r4.0-standard:2022.11.1-b2 sha256:1e6145623769ab4070b792839662b8394ef711a062797c82e8144e3525bf32e9 1Gi  true
dockerPushOnly 268 container.repository.cloudera.com/cdp-private/cloudera/cdsw/ml-runtime-workbench-r4.1-standard:2022.11.1-b2 cloudera/cdsw/ml-runtime-workbench-r4.1-standard:2022.11.1-b2 sha256:31b90dfab2c16080deed173f7926a405c3823abfab58cda71bec7051b726b2dc 1Gi  true
dockerPushOnly 269 container.repository.cloudera.com/cdp-private/cloudera/cdsw/ml-runtime-workbench-scala2.11-standard:2022.11.1-b2 cloudera/cdsw/ml-runtime-workbench-scala2.11-standard:2022.11.1-b2 sha256:2a270198f7249069c738cd01ff3c2de75f47a910dccd50d351b3c159eb9cd747 979Mi  true
dockerPushOnly 270 container.repository.cloudera.com/cdp-private/cloudera/cdv/runtimedataviz:7.0.3-b57 cloudera/cdv/runtimedataviz:7.0.3-b57 sha256:25e5642df42ccc3f715262764971dae7c095fed5bb574c3b3c662520fe9ef632 3Gi  true

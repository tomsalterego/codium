#!/usr/bin/env bash
# shellcheck disable=SC2129

set -e

# git workaround
if [[ "${CI_BUILD}" != "no" ]]; then
  git config --global --add safe.directory "/__w/$( echo "${GITHUB_REPOSITORY}" | awk '{print tolower($0)}' )"
fi

if [[ -n "${PULL_REQUEST_ID}" ]]; then
  BRANCH_NAME=$( git rev-parse --abbrev-ref HEAD )

  git config --global user.email "$( echo "${GITHUB_USERNAME}" | awk '{print tolower($0)}' )-ci@not-real.com"
  git config --global user.name "${GITHUB_USERNAME} CI"
  git fetch --unshallow
  git fetch origin "pull/${PULL_REQUEST_ID}/head"
  git checkout FETCH_HEAD
  git merge --no-edit "origin/${BRANCH_NAME}"
fi

if [[ -z "${RELEASE_VERSION}" ]]; then
  if [[ "${VSCODE_LATEST}" == "yes" ]] || [[ ! -f "${VSCODE_QUALITY}.json" ]]; then
    echo "Retrieve lastest version"
    #UPDATE_INFO=$( curl --silent --fail "https://update.code.visualstudio.com/api/update/darwin/${VSCODE_QUALITY}/0000000000000000000000000000000000000000" )
  else
    echo "Get version from ${VSCODE_QUALITY}.json"
    MS_COMMIT="5437499feb04f7a586f677b155b039bc2b3669eb"
    MS_TAG="1.90.2"
  fi

  if [[ -z "${MS_COMMIT}" ]]; then
    MS_COMMIT="5437499feb04f7a586f677b155b039bc2b3669eb"
    MS_TAG="1.90.2"

    if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
      MS_TAG="1.90.2"
    fi
  fi

  date=$( date +%Y%j )

  if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
    RELEASE_VERSION="${MS_TAG}.${date: -5}-insider"
  else
    RELEASE_VERSION="${MS_TAG}.${date: -5}"
  fi
else
  if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
    if [[ "${RELEASE_VERSION}" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\.[0-9]+-insider$ ]];
    then
      MS_TAG="1.90.2"
    else
      echo "Error: Bad RELEASE_VERSION: ${RELEASE_VERSION}"
      exit 1
    fi
  else
    if [[ "${RELEASE_VERSION}" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\.[0-9]+$ ]];
    then
      MS_TAG="1.90.2"
    else
      echo "Error: Bad RELEASE_VERSION: ${RELEASE_VERSION}"
      exit 1
    fi
  fi

  if [[ "${MS_TAG}" == "$( jq -r '.tag' "${VSCODE_QUALITY}".json )" ]]; then
    MS_COMMIT="5437499feb04f7a586f677b155b039bc2b3669eb"
  else
    echo "Error: No MS_COMMIT for ${RELEASE_VERSION}"
    exit 1
  fi
fi

echo "RELEASE_VERSION=\"${RELEASE_VERSION}\""

mkdir -p vscode
cd vscode || { echo "'vscode' dir not found"; exit 1; }

git init -q
git remote add origin https://github.com/Microsoft/vscode.git

# figure out latest tag by calling MS update API
if [[ -z "${MS_TAG}" ]]; then
  #UPDATE_INFO=$( curl --silent --fail "https://update.code.visualstudio.com/api/update/darwin/${VSCODE_QUALITY}/0000000000000000000000000000000000000000" )
  MS_COMMIT="5437499feb04f7a586f677b155b039bc2b3669eb"
  MS_TAG="1.90.2"
elif [[ -z "${MS_COMMIT}" ]]; then
  REFERENCE=$( git ls-remote --tags | grep -x ".*refs\/tags\/${MS_TAG}" | head -1 )

  if [[ -z "${REFERENCE}" ]]; then
    echo "Error: The following tag can't be found: ${MS_TAG}"
    exit 1
  elif [[ "${REFERENCE}" =~ ^([[:alnum:]]+)[[:space:]]+refs\/tags\/([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
    MS_COMMIT="5437499feb04f7a586f677b155b039bc2b3669eb"
    MS_TAG="1.90.2"
  else
    echo "Error: The following reference can't be parsed: ${REFERENCE}"
    exit 1
  fi
fi

echo "MS_TAG=\"${MS_TAG}\""
echo "MS_COMMIT=\"${MS_COMMIT}\""

git fetch --depth 1 origin "${MS_COMMIT}"
git checkout FETCH_HEAD

cd ..

# for GH actions
if [[ "${GITHUB_ENV}" ]]; then
  echo "MS_TAG=${MS_TAG}" >> "${GITHUB_ENV}"
  echo "MS_COMMIT=${MS_COMMIT}" >> "${GITHUB_ENV}"
  echo "RELEASE_VERSION=${RELEASE_VERSION}" >> "${GITHUB_ENV}"
fi

export MS_TAG
export MS_COMMIT
export RELEASE_VERSION

echo "MS_TAG=\"${MS_TAG}\"" > build.env
echo "MS_COMMIT=\"${MS_COMMIT}\"" >> build.env
echo "RELEASE_VERSION=\"${RELEASE_VERSION}\"" >> build.env

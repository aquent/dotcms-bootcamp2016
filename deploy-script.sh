#!/bin/bash
## For testing only - do not put in Jenkins
## Jenkins Git plugin sets these variables for us
GIT_PREVIOUS_COMMIT="cf80ff6924f4b8afe7f08504ecb7ff546299223b"
GIT_COMMIT="ac354e5301fd51dee381577aa5079ae42ca81115"

## Start processing the commits
echo "Last Commit: $GIT_PREVIOUS_COMMIT"
echo "This Commit: $GIT_COMMIT"

## dotCMS's API Endpoint
api="http://dotcms-dev-app1a.aquent.com/api/content/publish/1"

## deleteFileResource API Endpoint
dapi="http://dotcms-dev-app1a.aquent.com/api/aqresource/delete-id/"

## The host where we have the get-file-id script
assets_host="http://dev-assets.aquent.com"

## Username and Password for dotCMS's API
## You should probably use a .netrc file for curl instead of hardcoding this here
api_user="some-user@aquent.com"
api_pass="****"

## List of Source Hosts
sourcehosts=(
    "aquent.com"
    "vitamintalent.com"
    "thetalentcalendar.com"
)
## List of compiled files to upload for each host
sourcefiles=(
    "/css:main.css"
    "/css:main.min.css"
    "/css:main.min.css.map"
    "/js:app.js"
    "/js:app.min.js"
    "/js:app.min.js.map"
)
sfregex="(.*):(.*)"

## Flags for building source on each host
## Set in the script below if detected in changeset
has_aq_src=false
has_vt_src=false
has_tc_src=false

## If we have any source to build
## Set in the script below if detected in changeset
gulp_build=false

## Trim function
trim() {
  local orig="$1"
  local trmd=""
  while true;
  do
    trmd="${orig#[[:space:]]}"
    trmd="${trmd%[[:space:]]}"
    test "$trmd" = "$orig" && break
    orig="$trmd"
  done
  printf -- '%s\n' "$trmd"
}

## Get a file's id
getFileId() {
  local host="$1"
  local path="$2"
  local filename="$3"
  local resp=$(curl -s -u ${api_user}:${api_pass} "${assets_host}/apps/get-file-id?host=${host}&path=${path}/${filename}")
  echo $(trim "${resp}")
}
## The format that getFileId() returns
host_file_regex=":(.*):(.*):"

## Upload a file to dotCMS
uploadFile() {
  local host="$1"
  local path="$2"
  local filename="$3"
  local filepath="$4"
  local resp=$(getFileId "${host}" "${path}" "${filename}")
  if [[ $resp =~ $host_file_regex ]] ; then
    local host_id="${BASH_REMATCH[1]}"
    local file_id="${BASH_REMATCH[2]}"
    if [ ! -z $host_id ] ; then
      if [ ! -z $file_id ] ; then
        echo "** File ID = ${file_id} - Updating File"
        curl -s -u ${api_user}:${api_pass} ${api} -XPUT \
          -F 'json={stName:"fileAsset",hostFolder:"'"${host}:${path}/"'",title="'"${filename}"'",identifier="'"${file_id}"'",languageId:1};type=application/json' \
          -F file=@"${filepath}"
      else
        echo "** No File ID - New File"
        curl -s -u ${api_user}:${api_pass} ${api} -XPUT \
          -F 'json={stName:"fileAsset",hostFolder:"'"${host}:${path}/"'",title="'"${filename}"'",languageId:1};type=application/json' \
          -F file=@"${filepath}"
      fi
    else
      echo "** There is no hostId so we can't do anything"
    fi
  else
    echo "** Host:File Response did not match"
  fi
}

## Delete a file in dotCMS
deleteFile() {
  local host="$1"
  local path="$2"
  local filename="$3"
  echo "** Deleting ${path}/${filename} to ${host} over ${dapi} with ${api_user}"
  local resp=$(getFileId "${host}" "${path}" "${filename}")
  if [[ $resp =~ $host_file_regex ]] ; then
    local host_id="${BASH_REMATCH[1]}"
    local file_id="${BASH_REMATCH[2]}"
    if [ ! -z $host_id ] ; then
      if [ ! -z $file_id ] ; then
        echo "** File ID = ${file_id} - Deleting File"
        curl -s -u ${api_user}:${api_pass} -XGET ${dapi}${file_id}
      else
        ## Not necessarily an error because the file could've been manually deleted by a dev
        echo "** No fileId so we can't delete it"
      fi
    else
      echo "** There is no hostId so we can't do anything"
    fi
  else
    echo "** Host:File Response did not match"
  fi
}

## Get the list of changed files from github
files="$(git diff --name-status ${GIT_PREVIOUS_COMMIT} ${GIT_COMMIT})"

## Loop over the file changes
while read -r diff; do
  ## Parse the diff message
  diff_regex="([MCRADU])[[:space:]]+(.*)"
  if [[ $diff =~ $diff_regex ]] ; then
    diff_type="${BASH_REMATCH[1]}"
    file="${BASH_REMATCH[2]}"
    path=$(dirname "${file}")
    filename=$(basename "${file}")
    is_src=false
    deploy_site=""

    echo "=========="
    echo "Change type = ${diff_type}"
    echo "Path        = ${path}"
    echo "Filename    = ${filename}"

    ## See if this s a src file
    if [[ $path == src/* ]] ; then
      deploy_site=$(echo $path | perl -n -e'/src\/([^\/]*)(\/?.*)/ && print $1')
      deploy_path=$(echo $path | perl -n -e'/src\/([^\/]*)(\/?.*)/ && print $2')
      is_src=true
      gulp_build=true
    fi

    ## See if this is a dist file
    if [[ $path == dist/* ]] ; then
      deploy_site=$(echo $path | perl -n -e'/dist\/([^\/]*)(\/?.*)/ && print $1')
      deploy_path=$(echo $path | perl -n -e'/dist\/([^\/]*)(\/?.*)/ && print $2')
    fi

    echo "Deploy Site = ${deploy_site}"
    echo "Deploy Path = ${deploy_path}"

    ## if deploy site is not set then it isn't something we need to deploy
    if [ -n $deploy_site ] ; then
      ## Handle the non src files
      if [ "$is_src" = false ]
      then
        ## handle each type of change
        case $diff_type in
          [MCRA])
            ## M=Modified, C=Copied+Changed, R=Renamed, A=Added
            echo "Deploying ${deploy_path}/${filename} on ${deploy_site} ..."
            uploadFile "${deploy_site}" "${deploy_path}" "${filename}" "${file}"
            echo "... Finished"
            ## At some point we should try and see if we can handle R better, like remove the old file
            ;;
          [D])
            ## D=Deleted
            echo "Deleting ${deploy_path}/${filename} from ${deploy_site} ..."
            deleteFile "${deploy_site}" "${deploy_path}" "${filename}"
            echo "... Finished"
            ;;
          *)
            ## Could be U=Unmerged or something went wrong
            echo "Unrecognized Diff Type: ${diff_type}"
            echo "Skipping ${deploy_path}/${filename} on ${deploy_site}"
            ;;
        esac
      else
        echo "${deploy_path}/${filename} on ${deploy_site} is a source file"
        ## Check for the host
        case $deploy_site in
          aquent.com)
            has_aq_src=true
            ;;
          vitamintalent.com)
            has_vt_src=true
            ;;
          thetalentcalendar.com)
            has_tc_src=true
            ;;
          *)
            echo "Unknown src host = ${deploy_site}"
            ;;
        esac
      fi
    else
      echo "Unknown Path"
    fi
  else
    echo "Diff Pattern does not match - ${diff}"
  fi
done <<< "$files"

## Check to see if we need to handle source files or not
echo "=========="
if [ "$gulp_build" = true ] ; then
  ## Need to compile the source and upload the CSS/JS files
  echo "Building Source Files"
  if [ "${has_aq_src}" = true ] ; then
    echo "Building AQ src ..."
    gulp -h "aquent.com"
    echo "... Finished AQ src"
  else
    echo "No AQ src"
  fi
  echo "==="
  if [ "${has_vt_src}" = true ] ; then
    echo "Building VT src ..."
    gulp -h "vitamintalent.com"
    echo "... Finished VT src"
  else
    echo "No VT src"
  fi
  echo "==="
  if [ "${has_tc_src}" = true ] ; then
    echo "Building TC src ..."
    gulp -h "thetalentcalendar.com"
    echo "... Finished TC src"
  else
    echo "No TC src"
  fi
  echo "==="
  echo "Finished Building Source Files"
  echo "=========="
  echo "Deploying Compiled Files"
  ## Loop through the hosts
  for h in ${sourcehosts[*]} ; do
    echo "====="
    echo "Checking for deploy on ${h}"
    ## Make sure we are deploying to this host
    doit=false
    case $h in
      aquent.com)
        echo "${h} is AQ"
        if [ "$has_aq_src" = true ] ; then
          doit=true
          echo "Deploying AQ src"
        else
          echo "Not Deploying AQ src"
        fi
        ;;
      vitamintalent.com)
        echo "${h} is VT"
        if [ "$has_vt_src" = true ] ; then
          doit=true
          echo "Deploying VT src"
        else
          echo "Not Deploying VT src"
        fi
        ;;
      thetalentcalendar.com)
        echo "${h} is TC"
        if [ "$has_tc_src" = true ] ; then
          doit=true
          echo "Deploying TC src"
        else
          echo "Not Deploying TC src"
        fi
        ;;
      *)
        echo "Unknown src host = ${h}"
        ;;
    esac
    if [ "$doit" = true ] ; then
      ## Loop through the list and upload each one
      for i in ${sourcefiles[*]} ; do
        echo "==="
        echo "Processing File: $i on $h"
        ## Parse the file into host/path/name
        if [[ $i =~ $sfregex ]] ; then
          file_path="${BASH_REMATCH[1]}"
          file_name="${BASH_REMATCH[2]}"
          file="dist/${h}${file_path}/${file_name}"
          echo "Uploading File: ${file} ..."
          uploadFile "${h}" "${file_path}" "${file_name}" "${file}"
          echo "... Uploaded"
        else
          echo "No Match"
        fi
      done ## end loop through files
    else
      echo "Not Deploying to ${h}"
    fi
  done ## end loop through hosts
else
  echo "No source Files to deploy"
fi
echo "=========="

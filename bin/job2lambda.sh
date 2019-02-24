#!/usr/bin/env bash

set -e
set -u
set -o pipefail

job2lambda_path=$(readlink -e "${BASH_SOURCE[0]}")
job2lambda_dir="${job2lambda_path%/*}"

source "${job2lambda_dir}/tcf-env.sh"

#source util.sh
source "${job2lambda_dir}/${UTIL_RELATIVE_PATH}util${RESOURCE_VERSION}.sh"

#source "tcf-package.sh"
source "${job2lambda_dir}/tcf-package${RESOURCE_VERSION}.sh"

if [ "${1:-}" == "-h" ] || [ "${1:-}" == "--h" ] || [ "${1:-}" == "-help" ] || [ "${1:-}" == "--help" ] || [ "${1:-}" == "-?" ] ; then
    declare usage="./job2lambda <s3_bucket> <job_zip_path> [ <job_zip_target_dir> [ <working_dir> [ <description> [ <license> ] ] ] ]"
    echo "${usage}"
    exit
fi

declare s3_bucket="${1:-}"
declare job_zip_path="${2:-}"
declare job_zip_target_dir="${3:-}"
declare working_dir="${4:-}"
declare description="${5:-no description provided}"
declare license="${6:-no license specified}"

required s3_bucket job_zip_path

export INFO_LOG=true
export DEBUG_LOG=true

declare aws_command
which aws
if [ $? -ne 0 ]; then
   aws_command="/opt/aws"
else
   aws_command="aws"
fi


${aws_command} --version
python --version
python2 --version
python3 --version
python2.7 --version
python3.7 --version


declare job_file_name
declare job_file_root
declare job_root
declare job_root_pattern="-+([0-9])\.+([0-9])\.+([0-9])*"

parse_job_zip_path "${job_zip_path}" "${job_root_pattern}" job_file_name job_file_root job_root

infoLog "Creating lambda layer zip file: job_to_lambda '${job_zip_path}' '${job_zip_target_dir}' '${working_dir}'" 
job_to_lambda "${job_zip_path}" "${job_zip_target_dir}" "${working_dir}"

infoLog "Copying lambda layer zip file to s3: ${aws_command} s3 cp '${job_zip_target_dir}/${job_file_root}.zip' 's3://${s3_bucket}/${job_root}/${job_file_name}'"
"${aws_command}" s3 cp "${job_zip_target_dir}/${job_file_root}.zip" "s3://${s3_bucket}/${job_root}/${job_file_name}"

cat <<EOF

Creating lambda layer:

${aws_command} lambda publish-layer-version \
    --layer-name "${job_root}" \
    --description "${description}" \
    --license-info "${license}" \
    --compatible-runtimes "java8" \
    --content "S3Bucket=${s3_bucket},S3Key=${job_root}/${job_file_name}"

EOF


${aws_command} lambda publish-layer-version \
    --layer-name "${job_root}" \
    --description "${description}" \
    --license-info "${license}" \
    --compatible-runtimes "java8" \
    --content "S3Bucket=${s3_bucket},S3Key=${job_root}/${job_file_name}"


infoLog "Finished"


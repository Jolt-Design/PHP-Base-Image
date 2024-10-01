#!/bin/sh

PROJECT_NAME=$(${TERRAFORM_COMMAND:-terraform} output -raw codebuild_project_name)

AWS_PAGER= ${AWS_COMMAND:-aws} codebuild start-build --project-name=$PROJECT_NAME

echo "Tailing build logs, nothing will show until source download completes (ctrl-c to cancel)..."

${AWS_COMMAND:-aws} logs tail --follow --since=0s /aws/codebuild/$PROJECT_NAME

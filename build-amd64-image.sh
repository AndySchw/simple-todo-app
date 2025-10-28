#!/bin/bash

# Script to build AMD64 Docker image on EC2 and push to ECR
# This script should be run ON an AMD64 EC2 instance

set -e

REGION="eu-north-1"
ACCOUNT_ID="539247487622"
REPO_NAME="todo-backend"
IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}:latest"

echo "Installing Docker and AWS CLI..."
sudo yum update -y
sudo yum install -y docker git
sudo service docker start
sudo usermod -a -G docker ec2-user

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install

echo "Logging into ECR..."
aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${IMAGE_URI}

echo "Cloning or using existing code..."
cd /tmp
# Assuming code is already uploaded or cloned

echo "Building Docker image for AMD64..."
docker build --platform linux/amd64 -t ${IMAGE_URI} .

echo "Pushing to ECR..."
docker push ${IMAGE_URI}

echo "Done! Image pushed successfully."

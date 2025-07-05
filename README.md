# aws_tf_check

Architecture

![image](https://github.com/user-attachments/assets/a642607a-ba22-49cd-a518-e30d12daa1b4)


Steps to create Producer / Consumer

Github Actions jobs

1. Infrastructure as code ( 

2. Docker image
   a. aws ecr create-repository --repository-name aws-check
   b. docker build -t microservice1:latest
   c. docker push

3. Deploy the images (deploy.yml)


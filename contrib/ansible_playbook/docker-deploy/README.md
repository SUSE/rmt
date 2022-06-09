docker-deploy
=============

This role deploys applications via Docker containers and/or builds Docker images. Docker CLI or Docker Compose is used to deploy the containers for the application and Docker Build is used to create the Docker images. This role handles various different applications by specifying a variables file in the `vars/` directory of the role that contains all of the necessary information to deploy the application or build the image.

Requirements
------------

* Repositories enabled on the target hosts so that Docker CLI and Docker Compose can be installed.
* A variables file in the `vars/` directory of the 'docker-deploy' Ansible role and specified via extra vars (For example, -e "@filename").

Role Variables
--------------

| Name | Type | Description |
| ---- | ---- | ----------- |
| General variables |  |  |
| aws_region | string | The AWS region that the AWS ECR registry resides in. |
| docker_container_become | bool | Whether to have the role become 'root', a different user, or the default user when running the Docker commands on the target host. |
| docker_registry_name | string | The name of the Docker registry to log into. |
| docker_registry_username | string | The username to use when authenticating with the Docker registry specified in the 'docker_registry_name' variable (Not used when AWS ECR is used as the Docker registry). |
| docker_registry_password | string | The password to use when authenticating with the Docker registry specified in the 'docker_registry_name' variable (Not used when AWS ECR is used as the Docker registry). |
| docker_image | string | The 'registry/name' of the Docker image to pull for the containers. For example: 'gitlab/gitlab-ee:latest' |
| Docker Build variables |  |  |
| docker_build_image | bool | Whether to use Docker Build to create a Docker image from a dockerfile. |
| docker_build_template_filename | string | The name of the dockerfile within the 'templates/' directory to use when building a Docker image (For example, 'concourse-ubuntu/dockerfile.j2'). |
| docker_build_push | bool | Whether to push the Docker image to the registry after it is built via Docker Build. |
| Container variables |  |  |
| docker_create_container | bool | Whether to create a Docker container using either of the two methods: Docker CLI or Docker Compose. |
| docker_compose | bool | Whether to use Docker Compose to create the container. |
| docker_compose_template_filename | string | The name of the Docker Compose template file to use if the 'docker_compose' is set to true. |
| docker_compose_directory | string | The directory in which to place the 'docker-compose.yml' file on the target system. |
| container_name | string | The name to use for the container once it is created. |
| container_restart_policy | string | The container restart policy. Valid options are 'no' (The default if nothing is specified), 'always', 'on-failure', and 'unless-stopped'. |
| container_hostname | string | The hostname to set for the container. |
| container_environment_variables | dict | A dictionary of dictionaries defining environment variables to pass to the containers. |
| container_ports | string | A list of ports to publish to the host for the container. |
| container_volumes | string | A list of volumes defined for the container. |

Dependencies
------------

* If pulling secrets from Vault, a Vault server and valid Vault token is required along with the `vault-auth` Ansible role.
* If using AWS ECR, an ECR repository must be setup and an image stored within it ahead of time.
* If using AWS ECR, either an IAM role attached to the target hosts granting access to AWS ECR or AWS access and secret keys specified in the `aws_access_key`, `aws_secret_key` and optionally `aws_session_token` Ansible variables (Use the `vault-auth` role for supplying these values).

Notes
-----

**Adding a New Application to Deploy Containers for:** Docker CLI or Docker Compose can be used to deploy almost any application via Docker containers. To add a new application, follow these steps:

1. Decide whether you're going to use Docker CLI or Docker Compose to create the container for the application. Docker Compose is the preferred method due to the container configuration being easier to customize and more clear.

2. Create a variables file for the new application in the `vars/` directory of the role. The variables listed in this file will overwrite variables set almost anywhere else except for extra vars passed via the command line. Users are encouraged to put any/all variables in this file (Do not put values for the variables that handle secrets). Make sure to specify values in your variables file for the relevant variables under the `# Container related variables #` section of the defaults variable file.

3. If using Docker Compose, add a copy of your `docker-compose.yml` file to the `templates/` directory of the role, creating a subdirectory named the same thing as your application. Append the `.j2` file extension to the `docker-compose.yml` file so that it is recognized as a Jinja template file (For example: `templates/gitlab/docker-compose.yml.j2`). Create variables for any values in the `docker-compose.yml.j2` file that you'd like and make sure they are set in the variables file that was created in step 2.

4. Run the role specifying the variables file name via `-e "@vars-filename"` extra vars (For example: `ansible-playbook -i 10.0.0.2, docker-deploy.yml -e "@gitlab.yml"`).

Generic copies of the application's variables files can be placed in the root of the `vars/` directory within the role. If the variables file has environment specific values in it, then create a subdirectory within the `vars/businesses/` directory for that environment and place the variables file in there (For example: `vars/businesses/REDACTED/gitlab.yml`).

**Building a New Docker Image:** To build a new Docker image using this role, follow these steps:

1. Create a variables file for the new Docker image in the `vars/` directory of the role. The variables listed in this file will overwrite variables set almost anywhere else except for extra vars passed via the command line. Users are encouraged to put any/all variables in this file (Do not put values for the variables that handle secrets). Make sure to specify values in your variables file for the variables under the `# Docker Build related variables #` section of the defaults variable file.

2. Add a copy of your `dockerfile` to the `templates/` directory of the role, creating a subdirectory named the same thing as the name of the Docker image to be built. Append the `.j2` file extension to the `dockerfile` file name so that it is recognized as a Jinja template file (For example: `templates/concourse-ubuntu/dockerfile.j2`). Create variables for any values in the `dockerfile.j2` file that you'd like and make sure they are set in the variables file that was created in step 1.

3. Run the role specifying the variables file name via `-e "@vars-filename"` extra vars (For example: `ansible-playbook -i 10.0.0.2, docker-deploy.yml -e "@gitlab.yml"`).

Generic copies of the Docker image's variables files can be placed in the root of the `vars/` directory within the role. If the variables file has environment specific values in it, then create a subdirectory within the `vars/businesses/` directory for that environment and place the variables file in there (For example: `vars/businesses/REDACTED/concourse-ubuntu.yml`).

**Variables Files:** This role uses variables files saved in the `vars/` directory of the role to deploy different applications and build different Docker images. Each application that is to be deployed or Docker image that is built via this role should have a variables file created for it, and all relevant Ansible variables for it should be placed in there. The variables in the variables file are loaded via the `-e "@vars-filename"` extra vars option of the `ansible-playbook` command. If your variables file is setup properly and contains all of the necessary variables, ideally the only variable that the user must specify via extra vars is the variables file name/path.

**Docker CLI:** One of the two methods for deploying Docker containers is using the Docker CLI. To use Docker CLI to deploy the container, set the `docker_create_container` variable to `true` and set the `docker_compose` variable to `false`. The only other variable that is required is the `docker_image` variable, which is the name of the Docker image to use for the container. Other container related variables are optional. As explained above, a variables file should be used to set all of the container's necessary variables.

**Environment Variables File:** One of the optional Ansible variables that can be used when deploying containers via Docker CLI is the `container_environment_variables` variable. This variable allows the user to dynamically build an environment variables file that is then passed to the container upon creation by Docker CLI. The role will loop through the dictionaries underneath the `container_environment_variables` variable and create environment variables for each one, where the name of the environment variable is the dictionary's key, and the value of the environment variable is the dictionary's value. See the following for an example:

```
container_environment_variables:
  AWS_DEFUALT_REGION: 'us-gov-west-1'
  GITLAB_HOME: '/srv/gitlab'
```

**Docker Compose:** The second method of deploying Docker containers is using Docker Compose and a [Docker Compose file](https://docs.docker.com/compose/) to create a container or a series of containers. Docker Compose has the advantage of being able deploy multiple containers in one run of the role. For example, two different containers can be created at once where one container handles the web application and the other handles the backend database. To use Docker Compose to deploy the containers, create a Docker Compose file in the `templates/` directory of the role under a subdirectory named the same thing as the name of the application that is to be deployed. Append the `.j2` file extension to the `docker-compose.yml` filename so that it is recognized as a Jinja template file (For example: `templates/gitlab/docker-compose.yml.j2`). Write this Docker Compose file as you normally would write any Docker Compose file, except Jinja variables and filters can also be used. Just as you would with a Docker CLI deployment, create a variables file for the deployment under the `vars/` directory of the role, and in there set the `docker_create_container` and `docker_compose` variables to `true`, and set the `docker_compose_template_filename` variable to the name/path of the `docker-compose.j2` file.

**AWS ECR:** To pull images from AWS Elastic Container Registry (ECR), first ensure that the target host has either an IAM role or an access and secret key configured that allows pulling images from ECR. Put the ECR registry name in the `docker_registry_name` variable (For example: `docker_registry_name: '123456789012.dkr.ecr.us-gov-west-1.amazonaws.com'`) and put the AWS region in the `aws_region` variable. Once the role is ran, Docker will log into the AWS ECR registry and pull the Docker image specified in the `docker_image` variable from there.

Example Playbook
----------------

This example will deploy GitLab on Docker containers. This is done by specifying the `gitlab.yml` variables file that is stored in the `vars/` directory.
```
---
- hosts: all
  gather_facts: true
  vars:

  pre_tasks:

    - name: Run the 'repository-management' role to enable base repositories
      include_role:
        name: ../../roles/repository-management
      vars:
        application_preset_selection: 'base'
        redhat_repo: 'true'
        epel_repo: 'true'
        repo_enable: 'true'

  tasks:

    - name: Run the 'docker-deploy' role
      include_role:
        name: ../roles/docker-deploy

...
```

Author Information
------------------

* REDACTED (REDACTED)

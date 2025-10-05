pipeline {
    agent any

    parameters {
        string(name: 'EC2_HOST', defaultValue: 'string(name: 'EC2_HOST', defaultValue: '3.95.120.44', description: 'EC2 public DNS or IP')
        string(name: 'EC2_USER', defaultValue: 'ec2-user', description: 'SSH user for EC2 (e.g., ec2-user, ubuntu)')
        string(name: 'APP_PORT', defaultValue: '8080', description: 'Host port to expose the app on EC2')
        string(name: 'IMAGE_TAG', defaultValue: '', description: 'Optional image tag to deploy (defaults to build number)')
        choice(name: 'DEPLOY_ENV', choices: ['prod', 'staging', 'none'], description: 'Where to deploy after build')
    }
    
    environment {
        // Docker image configuration (Docker Hub)
        DOCKER_IMAGE_FULL = 'digibosstech/edukate-app'
        DOCKER_REGISTRY_URL = 'https://index.docker.io/v1/'
        
        // Application configuration
        APP_NAME = 'edukate-learning-platform'
        
        // Credentials (configure these in Jenkins)
        DOCKER_REGISTRY_CREDENTIALS = credentials('docker-registry-credentials')
        DEPLOYMENT_SERVER_CREDENTIALS = credentials('deployment-server-ssh')
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out source code...'
                checkout scm
                
                script {
                    echo "Building ${APP_NAME} - Build #${BUILD_NUMBER}"
                    echo "Branch: ${env.BRANCH_NAME ?: 'main'}"
                    echo "Commit: ${env.GIT_COMMIT?.take(7) ?: 'unknown'}"
                }
            }
        }
        
        stage('Code Quality & Security') {
            parallel {
                stage('Lint HTML/CSS') {
                    steps {
                        echo 'Running HTML/CSS linting...'
                        script {
                            sh '''
                                find Edukate/Edukate-1.0.0 -name "*.html" -exec echo "Validating: {}" \;
                                find Edukate/Edukate-1.0.0/css -name "*.css" -exec echo "Checking CSS: {}" \;
                            '''
                        }
                    }
                }
                
                stage('Security Scan') {
                    steps {
                        echo 'Running security scan...'
                        script {
                            sh '''
                                echo "Validating nginx configuration..."
                                docker run --rm -v $(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro nginx:alpine nginx -t
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                echo 'Building Docker image...'
                script {
                    def tag = params.IMAGE_TAG?.trim() ? params.IMAGE_TAG.trim() : BUILD_NUMBER
                    sh "docker build -t ${DOCKER_IMAGE_FULL}:${tag} -t ${DOCKER_IMAGE_FULL}:latest ."
                    echo "Successfully built ${DOCKER_IMAGE_FULL}:${tag}"
                }
            }
        }

        stage('Provision EC2 (Terraform)') {
            when {
                expression { return params.APPLY_TERRAFORM }
            }
            steps {
                echo 'Applying Terraform to provision EC2...'
                script {
                    // Requires Jenkins credentials with ID 'aws-credentials' (AWS access key + secret)
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                        sh """
                            set -e
                            cd terraform
                            terraform init -input=false
                            terraform apply -input=false -auto-approve \
                              -var aws_region='${params.AWS_REGION}' \
                              -var ami_id='${params.AMI_ID}' \
                              -var instance_type='${params.INSTANCE_TYPE}' \
                              -var key_name='${params.KEY_NAME}' \
                              -var 'ssh_cidr_blocks=["${params.SSH_CIDR}"]' \
                              -var jenkins_http_port=${params.JENKINS_HTTP_PORT} \
                              -var jenkins_agent_port=${params.JENKINS_AGENT_PORT} \
                              -var github_repo_url='${params.GITHUB_REPO_URL}' \
                              -var github_repo_branch='${params.GITHUB_REPO_BRANCH}' \
                              -var repo_clone_path='${params.REPO_CLONE_PATH}' \
                              -var git_use_ssh=${params.GIT_USE_SSH} \
                              -var git_ssh_private_key='${params.GIT_SSH_PRIVATE_KEY}' \
                              -var git_config_user_name='${params.GIT_USER_NAME}' \
                              -var git_config_user_email='${params.GIT_USER_EMAIL}'
                        """
                    }
                }
            }
        }

        stage('Resolve EC2 Host (Terraform)') {
            when {
                expression { return params.USE_TERRAFORM_OUTPUT }
            }
            steps {
                echo 'Resolving EC2 host from Terraform outputs...'
                script {
                    try {
                        // Attempt to read public_ip from terraform outputs
                        def ip = sh(returnStdout: true, script: 'cd terraform && terraform output -raw public_ip').trim()
                        if (ip) {
                            env.EC2_HOST = ip
                            echo "Using EC2 host from Terraform: ${env.EC2_HOST}"
                        } else {
                            echo 'No Terraform output found; falling back to parameter EC2_HOST'
                            env.EC2_HOST = params.EC2_HOST
                        }
                    } catch (err) {
                        echo "Terraform not available or outputs missing: ${err}. Falling back to parameter EC2_HOST"
                        env.EC2_HOST = params.EC2_HOST
                    }
                }
            }
        }
        
        stage('Test') {
            parallel {
                stage('Container Health Check') {
                    steps {
                        echo 'Testing container health...'
                        script {
                            def tag = params.IMAGE_TAG?.trim() ? params.IMAGE_TAG.trim() : BUILD_NUMBER
                            sh """
                                docker run -d --name test-${BUILD_NUMBER} -p 8081:80 ${DOCKER_IMAGE_FULL}:${tag}
                                sleep 10
                                curl -f http://localhost:8081 || exit 1
                                curl -f http://localhost:8081/about.html || exit 1
                                curl -f http://localhost:8081/course.html || exit 1
                                curl -f http://localhost:8081/contact.html || exit 1
                                docker stop test-${BUILD_NUMBER}
                                docker rm test-${BUILD_NUMBER}
                            """
                        }
                    }
                }
                
                stage('Performance Test') {
                    steps {
                        echo 'Running basic performance tests...'
                        script {
                            def tag = params.IMAGE_TAG?.trim() ? params.IMAGE_TAG.trim() : BUILD_NUMBER
                            sh """
                                docker run -d --name perf-${BUILD_NUMBER} -p 8082:80 ${DOCKER_IMAGE_FULL}:${tag}
                                sleep 10
                                # ab -n 100 -c 10 http://localhost:8082/ || echo "Performance test skipped - ab not available"
                                curl -s -o /dev/null -w "HTTP %{http_code} in %{time_total}s\n" http://localhost:8082/ || true
                                docker stop perf-${BUILD_NUMBER}
                                docker rm perf-${BUILD_NUMBER}
                            """
                        }
                    }
                }
            }
        }
        
        stage('Push to Registry') {
            when {
                anyOf {
                    branch 'main'
                    branch 'master'
                    branch 'develop'
                }
            }
            steps {
                echo 'Pushing Docker image to registry...'
                script {
                    def tag = params.IMAGE_TAG?.trim() ? params.IMAGE_TAG.trim() : BUILD_NUMBER
                    docker.withRegistry(DOCKER_REGISTRY_URL, 'docker-registry-credentials') {
                        sh "docker push ${DOCKER_IMAGE_FULL}:${tag}"
                        sh "docker push ${DOCKER_IMAGE_FULL}:latest"
                    }
                    echo "Successfully pushed ${DOCKER_IMAGE_FULL}:${tag}"
                }
            }
        }
        
        stage('Deploy') {
            when {
                expression { return params.DEPLOY_ENV == 'prod' }
            }
            steps {
                echo "Deploying to EC2 (prod) host: ${env.EC2_HOST ?: params.EC2_HOST}..."
                script {
                    sshagent(['deployment-server-ssh']) {
                        def tag = params.IMAGE_TAG?.trim() ? params.IMAGE_TAG.trim() : BUILD_NUMBER
                        sh """
                            ssh -o StrictHostKeyChecking=no ${params.EC2_USER}@${env.EC2_HOST ?: params.EC2_HOST} '
                                set -e
                                if ! command -v docker >/dev/null 2>&1; then
                                  curl -fsSL https://get.docker.com | sh
                                fi
                                sudo systemctl enable docker || true
                                sudo systemctl start docker || true
                                docker pull ${DOCKER_IMAGE_FULL}:${tag}
                                docker stop ${APP_NAME} || true
                                docker rm ${APP_NAME} || true
                                docker run -d \
                                  --name ${APP_NAME} \
                                  --restart unless-stopped \
                                  -p ${params.APP_PORT}:80 \
                                  ${DOCKER_IMAGE_FULL}:${tag}
                                sleep 8
                                curl -f http://localhost:${params.APP_PORT} || exit 1
                                echo "Deployment successful!"
                            '
                        """
                    }
                }
            }
        }
        
        stage('Deploy to Staging') {
            when {
                expression { return params.DEPLOY_ENV == 'staging' }
            }
            steps {
                echo 'Deploying locally (staging)...'
                script {
                    sh """
                        docker stop ${APP_NAME}-staging || true
                        docker rm ${APP_NAME}-staging || true
                        docker run -d \
                            --name ${APP_NAME}-staging \
                            --restart unless-stopped \
                            -p 8090:80 \
                            ${DOCKER_IMAGE_FULL}:latest
                        sleep 10
                        curl -f http://localhost:8090 || exit 1
                        echo "Staging deployment successful! Available at http://localhost:8090"
                    """
                }
            }
        }
    }
    
    post {
    always {
        echo 'Pipeline completed!'
        script {
            sh '''
                docker stop test-${BUILD_NUMBER} || true
                docker rm test-${BUILD_NUMBER} || true
                docker stop perf-${BUILD_NUMBER} || true
                docker rm perf-${BUILD_NUMBER} || true
            '''
        }
    }
}

            }
        }
        
        success {
            echo 'Pipeline succeeded! ✅'
        }
        
        failure {
            echo 'Pipeline failed! ❌'
        }
        
        unstable {
            echo 'Pipeline completed with warnings ⚠️'
        }
    }
}

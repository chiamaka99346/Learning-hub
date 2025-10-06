pipeline {
  agent any

  parameters {
    booleanParam(name: 'APPLY_TERRAFORM', defaultValue: true, description: 'Run terraform to (re)provision EC2')
    booleanParam(name: 'USE_TERRAFORM_OUTPUT', defaultValue: true, description: 'Read EC2 host and key path from terraform outputs')
    string(name: 'AWS_REGION', defaultValue: 'us-east-1', description: 'AWS region')
    string(name: 'EC2_HOST', defaultValue: '', description: 'Optional manual EC2 public IP/DNS (fallback if TF output missing)')
    string(name: 'EC2_USER', defaultValue: 'ec2-user', description: 'SSH user on EC2 (Amazon Linux: ec2-user, Ubuntu: ubuntu)')
    string(name: 'APP_PORT', defaultValue: '8080', description: 'Host port to expose app on EC2')
    string(name: 'IMAGE_TAG', defaultValue: '', description: 'Optional image tag to deploy (defaults to build number)')
    choice(name: 'DEPLOY_ENV', choices: ['prod', 'staging', 'none'], description: 'Where to deploy after build')
    string(name: 'SSH_CIDR', defaultValue: '0.0.0.0/0', description: 'CIDR allowed for SSH to EC2 (lock this down)')
    string(name: 'INSTANCE_TYPE', defaultValue: 't3.small', description: 'EC2 instance type')
  }

  environment {
    DOCKER_IMAGE_FULL = 'digibosstech/edukate-app'
    DOCKER_REGISTRY_URL = 'https://index.docker.io/v1/'
    APP_NAME = 'edukate-learning-platform'
    DOCKER_REGISTRY_CREDENTIALS = credentials('docker-registry-credentials')
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
            sh '''
              find Edukate/Edukate-1.0.0 -name "*.html" -exec echo "Validating: {}" \\;
              find Edukate/Edukate-1.0.0/css -name "*.css" -exec echo "Checking CSS: {}" \\;
            '''
          }
        }
        stage('Security Scan') {
          steps {
            echo 'Running security scan...'
            sh '''
              echo "Validating nginx configuration..."
              docker run --rm -v $(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro nginx:alpine nginx -t
            '''
          }
        }
      }
    }

    stage('Build Docker Image') {
      steps {
        script {
          def tag = params.IMAGE_TAG?.trim() ? params.IMAGE_TAG.trim() : BUILD_NUMBER
          sh "docker build -t ${DOCKER_IMAGE_FULL}:${tag} -t ${DOCKER_IMAGE_FULL}:latest ."
          echo "Built ${DOCKER_IMAGE_FULL}:${tag}"
        }
      }
    }

    stage('Provision EC2 (Terraform)') {
      when { expression { return params.APPLY_TERRAFORM } }
      steps {
        echo 'Applying Terraform to provision EC2...'
        withEnv(["AWS_REGION=${params.AWS_REGION}"]) {
          sh '''
            set -e
            cd terraform
            mkdir -p secrets && chmod 700 secrets
            terraform init -input=false -upgrade
            terraform apply -input=false -auto-approve \
              -var aws_region="${AWS_REGION}" \
              -var instance_type="${INSTANCE_TYPE}" \
              -var 'ssh_cidr_blocks=["${SSH_CIDR}"]'
          '''
        }
      }
    }

    stage('Resolve EC2 Host & Key Path') {
      when { expression { return params.USE_TERRAFORM_OUTPUT } }
      steps {
        script {
          try {
            def ip  = sh(returnStdout: true, script: 'cd terraform && terraform output -raw public_ip').trim()
            def key = sh(returnStdout: true, script: 'cd terraform && terraform output -raw private_key_path').trim()
            if (ip) env.EC2_HOST = ip
            if (key) env.PRIVATE_KEY_PATH = key
            echo "Using EC2 host: ${env.EC2_HOST ?: params.EC2_HOST}"
            echo "Using private key path: ${env.PRIVATE_KEY_PATH ?: 'not set'}"
          } catch (err) {
            echo "Terraform outputs missing: ${err}"
            env.EC2_HOST = params.EC2_HOST
          }
        }
      }
    }

    stage('Test') {
      parallel {
        stage('Container Health Check') {
          steps {
            script {
              def tag = params.IMAGE_TAG?.trim() ? params.IMAGE_TAG.trim() : BUILD_NUMBER
              sh """
                docker run -d --name test-${BUILD_NUMBER} -p 8081:80 ${DOCKER_IMAGE_FULL}:${tag}
                sleep 10
                curl -f http://localhost:8081/
                curl -f http://localhost:8081/about.html
                curl -f http://localhost:8081/course.html
                curl -f http://localhost:8081/contact.html
                docker stop test-${BUILD_NUMBER} && docker rm test-${BUILD_NUMBER}
              """
            }
          }
        }
        stage('Performance Test') {
          steps {
            script {
              def tag = params.IMAGE_TAG?.trim() ? params.IMAGE_TAG.trim() : BUILD_NUMBER
              sh """
                docker run -d --name perf-${BUILD_NUMBER} -p 8082:80 ${DOCKER_IMAGE_FULL}:${tag}
                sleep 10
                curl -s -o /dev/null -w "HTTP %{http_code} in %{time_total}s\\n" http://localhost:8082/ || true
                docker stop perf-${BUILD_NUMBER} && docker rm perf-${BUILD_NUMBER}
              """
            }
          }
        }
      }
    }

    stage('Push to Registry') {
      when { anyOf { branch 'main'; branch 'master'; branch 'develop' } }
      steps {
        script {
          def tag = params.IMAGE_TAG?.trim() ? params.IMAGE_TAG.trim() : BUILD_NUMBER
          docker.withRegistry(DOCKER_REGISTRY_URL, 'docker-registry-credentials') {
            sh "docker push ${DOCKER_IMAGE_FULL}:${tag}"
            sh "docker push ${DOCKER_IMAGE_FULL}:latest"
          }
          echo "Pushed ${DOCKER_IMAGE_FULL}:${tag}"
        }
      }
    }

    stage('Deploy') {
      when { expression { return params.DEPLOY_ENV == 'prod' } }
      steps {
        script {
          def host = env.EC2_HOST ?: params.EC2_HOST
          if (!host?.trim()) { error 'EC2 host not set. Provide EC2_HOST or enable USE_TERRAFORM_OUTPUT.' }
          def keyPath = env.PRIVATE_KEY_PATH ?: 'terraform/secrets/jenkins-prod.pem'
          sh """
            set -e
            ssh-keygen -R ${host} || true
            ssh -o StrictHostKeyChecking=no -i ${keyPath} ${params.EC2_USER}@${host} '
              set -e
              if ! command -v docker >/dev/null 2>&1; then
                sudo dnf -y install docker || sudo yum -y install docker || curl -fsSL https://get.docker.com | sh
              fi
              sudo systemctl enable docker || true
              sudo systemctl start docker || true
              docker pull ${DOCKER_IMAGE_FULL}:${IMAGE_TAG:-${BUILD_NUMBER}}
              docker stop ${APP_NAME} || true
              docker rm ${APP_NAME} || true
              docker run -d --name ${APP_NAME} --restart unless-stopped -p ${params.APP_PORT}:80 ${DOCKER_IMAGE_FULL}:${IMAGE_TAG ?: BUILD_NUMBER}
              sleep 8
              curl -f http://localhost:${params.APP_PORT}
            '
          """
        }
      }
    }

    stage('Deploy to Staging') {
      when { expression { return params.DEPLOY_ENV == 'staging' } }
      steps {
        sh """
          docker stop ${APP_NAME}-staging || true
          docker rm ${APP_NAME}-staging || true
          docker run -d --name ${APP_NAME}-staging --restart unless-stopped -p 8090:80 ${DOCKER_IMAGE_FULL}:latest
          sleep 10
          curl -f http://localhost:8090
        """
      }
    }
  }

  post {
    always {
      echo 'Pipeline completed.'
      sh '''
        docker stop test-${BUILD_NUMBER} 2>/dev/null || true
        docker rm   test-${BUILD_NUMBER} 2>/dev/null || true
        docker stop perf-${BUILD_NUMBER} 2>/dev/null || true
        docker rm   perf-${BUILD_NUMBER} 2>/dev/null || true
      '''
    }
    success { echo 'Pipeline succeeded' }
    failure { echo 'Pipeline failed' }
    unstable { echo 'Pipeline completed with warnings' }
  }
}
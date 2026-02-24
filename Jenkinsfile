pipeline {
    agent any

    options {
        timestamps()
    }

    parameters {
        string(name: 'AWS_REGION', defaultValue: 'eu-west-1', description: 'AWS region for ECR/ECS')
        string(name: 'AWS_ACCOUNT_ID', defaultValue: '', description: 'AWS account ID hosting ECR/ECS')
        string(name: 'ECR_REPOSITORY', defaultValue: 'cicd-node-app', description: 'ECR repository name')
        string(name: 'ECS_CLUSTER', defaultValue: 'cicd-node-cluster', description: 'ECS cluster name')
        string(name: 'ECS_SERVICE', defaultValue: 'cicd-node-service', description: 'ECS service name')
        string(name: 'ECS_TASK_FAMILY', defaultValue: 'cicd-node-app', description: 'ECS task definition family')
        string(name: 'ECS_EXECUTION_ROLE_ARN', defaultValue: '', description: 'ECS task execution role ARN')
        string(name: 'ECS_TASK_ROLE_ARN', defaultValue: '', description: 'ECS task role ARN')
        string(name: 'CLOUDWATCH_LOG_GROUP', defaultValue: '/ecs/cicd-node-app', description: 'CloudWatch log group for ECS container logs')
        choice(name: 'DEPLOYMENT_STRATEGY', choices: ['rolling'], description: 'Deployment strategy (rolling implemented in this pipeline)')
        booleanParam(name: 'APPLY_ECR_LIFECYCLE_POLICY', defaultValue: true, description: 'Apply ecs/ecr-lifecycle-policy.json to ECR')
        string(name: 'KEEP_ECS_REVISIONS', defaultValue: '10', description: 'Number of ECS task definition revisions to keep active')
    }

    environment {
        APP_NAME = 'cicd-node-app'
        REPORT_DIR = 'reports'
        SAST_DIR = 'reports/sast'
        SCA_DIR = 'reports/sca'
        IMAGE_DIR = 'reports/image'
        SECRET_DIR = 'reports/secret'
        SBOM_DIR = 'reports/sbom'
        DEPLOY_DIR = 'reports/deploy'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'mkdir -p ${SAST_DIR} ${SCA_DIR} ${IMAGE_DIR} ${SECRET_DIR} ${SBOM_DIR} ${DEPLOY_DIR}'
            }
        }

        stage('Validate Required Inputs') {
            steps {
                script {
                    def requiredParams = [
                        'AWS_ACCOUNT_ID': params.AWS_ACCOUNT_ID,
                        'ECS_EXECUTION_ROLE_ARN': params.ECS_EXECUTION_ROLE_ARN,
                        'ECS_TASK_ROLE_ARN': params.ECS_TASK_ROLE_ARN
                    ]
                    requiredParams.each { key, value ->
                        if (!value?.trim()) {
                            error("Missing required parameter: ${key}")
                        }
                    }
                }
            }
        }

        stage('Build Metadata') {
            steps {
                script {
                    env.SHORT_SHA = sh(script: 'git rev-parse --short=8 HEAD || echo localdev', returnStdout: true).trim()
                    env.BUILD_TAG_VERSION = "build-${env.BUILD_NUMBER}-${env.SHORT_SHA}"
                    env.ECR_URI = "${params.AWS_ACCOUNT_ID}.dkr.ecr.${params.AWS_REGION}.amazonaws.com/${params.ECR_REPOSITORY}"
                    env.IMAGE_URI = "${env.ECR_URI}:${env.BUILD_TAG_VERSION}"
                }
            }
        }

        stage('Install') {
            steps {
                sh 'npm ci'
            }
        }

        stage('Unit Tests') {
            steps {
                sh 'npm test -- --coverage'
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'test-results/*.xml'
                    archiveArtifacts allowEmptyArchive: true, artifacts: 'coverage/**'
                }
            }
        }

        stage('SAST - SonarQube') {
            steps {
                withSonarQubeEnv('sonarqube') {
                    sh '''
                      sonar-scanner \
                        -Dsonar.projectKey=${APP_NAME} \
                        -Dsonar.projectVersion=${BUILD_TAG_VERSION}
                    '''
                }
            }
        }

        stage('SAST Quality Gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Secret Scan - Gitleaks') {
            steps {
                sh '''
                  docker run --rm -v "$PWD:/repo" gitleaks/gitleaks:latest detect \
                    --source /repo \
                    --report-format json \
                    --report-path /repo/${SECRET_DIR}/gitleaks-report.json \
                    --exit-code 0
                '''
            }
        }

        stage('SCA - OWASP Dependency-Check') {
            steps {
                sh '''
                  docker run --rm -v "$PWD:/src" owasp/dependency-check:latest \
                    --scan /src \
                    --project ${APP_NAME} \
                    --format JSON \
                    --format HTML \
                    --out /src/${SCA_DIR}
                '''
            }
        }

        stage('SBOM - Syft') {
            steps {
                sh '''
                  docker run --rm -v "$PWD:/work" anchore/syft:latest dir:/work \
                    -o cyclonedx-json=/work/${SBOM_DIR}/sbom-cyclonedx.json
                '''
            }
        }

        stage('Build Container') {
            steps {
                sh '''
                  docker build \
                    --build-arg VERSION=${BUILD_TAG_VERSION} \
                    -t ${APP_NAME}:${BUILD_TAG_VERSION} .
                '''
            }
        }

        stage('Image Scan - Trivy') {
            steps {
                sh '''
                  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                    -v "$PWD:/work" aquasec/trivy:latest image \
                    --format json \
                    --output /work/${IMAGE_DIR}/trivy-image.json \
                    ${APP_NAME}:${BUILD_TAG_VERSION}
                '''
            }
        }

        stage('Security Gate') {
            steps {
                sh 'node scripts/security-gate.js'
            }
        }

        stage('ECR Login and Push') {
            steps {
                sh '''
                  aws ecr describe-repositories --repository-names ${ECR_REPOSITORY} --region ${AWS_REGION} >/dev/null 2>&1 || \
                    aws ecr create-repository --repository-name ${ECR_REPOSITORY} --region ${AWS_REGION} >/dev/null

                  aws ecr get-login-password --region ${AWS_REGION} | \
                    docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

                  docker tag ${APP_NAME}:${BUILD_TAG_VERSION} ${IMAGE_URI}
                  docker tag ${APP_NAME}:${BUILD_TAG_VERSION} ${ECR_URI}:latest
                  docker tag ${APP_NAME}:${BUILD_TAG_VERSION} ${ECR_URI}:sha-${SHORT_SHA}

                  docker push ${IMAGE_URI}
                  docker push ${ECR_URI}:latest
                  docker push ${ECR_URI}:sha-${SHORT_SHA}

                  printf '%s' "${IMAGE_URI}" > ${DEPLOY_DIR}/image-uri.txt
                '''
            }
        }

        stage('Apply ECR Lifecycle') {
            when {
                expression { return params.APPLY_ECR_LIFECYCLE_POLICY }
            }
            steps {
                sh '''
                  aws ecr put-lifecycle-policy \
                    --repository-name ${ECR_REPOSITORY} \
                    --lifecycle-policy-text file://ecs/ecr-lifecycle-policy.json \
                    --region ${AWS_REGION} > ${DEPLOY_DIR}/ecr-lifecycle-policy.json
                '''
            }
        }

        stage('Render ECS Task Definition') {
            steps {
                sh '''
                  IMAGE_URI=${IMAGE_URI} \
                  TASK_FAMILY=${ECS_TASK_FAMILY} \
                  EXECUTION_ROLE_ARN=${ECS_EXECUTION_ROLE_ARN} \
                  TASK_ROLE_ARN=${ECS_TASK_ROLE_ARN} \
                  AWS_REGION=${AWS_REGION} \
                  LOG_GROUP=${CLOUDWATCH_LOG_GROUP} \
                  APP_VERSION=${BUILD_TAG_VERSION} \
                  scripts/render-ecs-taskdef.sh ecs/taskdef.template.json ${DEPLOY_DIR}/taskdef.rendered.json
                '''
            }
        }

        stage('Register ECS Task Definition') {
            steps {
                sh '''
                  aws ecs register-task-definition \
                    --cli-input-json file://${DEPLOY_DIR}/taskdef.rendered.json \
                    --region ${AWS_REGION} \
                    --query 'taskDefinition.taskDefinitionArn' \
                    --output text > ${DEPLOY_DIR}/taskdef-arn.txt
                '''
            }
        }

        stage('Deploy to ECS Service') {
            when {
                expression { return params.DEPLOYMENT_STRATEGY == 'rolling' }
            }
            steps {
                sh '''
                  TASK_DEF_ARN=$(cat ${DEPLOY_DIR}/taskdef-arn.txt)

                  aws ecs update-service \
                    --cluster ${ECS_CLUSTER} \
                    --service ${ECS_SERVICE} \
                    --task-definition "$TASK_DEF_ARN" \
                    --force-new-deployment \
                    --region ${AWS_REGION} > ${DEPLOY_DIR}/ecs-update-service.json

                  aws ecs wait services-stable \
                    --cluster ${ECS_CLUSTER} \
                    --services ${ECS_SERVICE} \
                    --region ${AWS_REGION}

                  aws ecs describe-services \
                    --cluster ${ECS_CLUSTER} \
                    --services ${ECS_SERVICE} \
                    --region ${AWS_REGION} > ${DEPLOY_DIR}/ecs-service-status.json
                '''
            }
        }

        stage('Cleanup Old ECS Revisions') {
            steps {
                sh 'scripts/cleanup-ecs-revisions.sh ${ECS_TASK_FAMILY} ${KEEP_ECS_REVISIONS}'
            }
        }
    }

    post {
        always {
            archiveArtifacts allowEmptyArchive: true, artifacts: 'reports/**/*, ecs/*.json, sonar-project.properties'
            sh '''
              docker image rm ${APP_NAME}:${BUILD_TAG_VERSION} 2>/dev/null || true
              docker image rm ${IMAGE_URI} 2>/dev/null || true
              docker image rm ${ECR_URI}:latest 2>/dev/null || true
              docker image rm ${ECR_URI}:sha-${SHORT_SHA} 2>/dev/null || true
            '''
        }
        success {
            echo 'Secure CI/CD pipeline completed and ECS service updated.'
        }
        failure {
            echo 'Pipeline failed. Deployment blocked by quality/security gate or runtime error.'
        }
    }
}

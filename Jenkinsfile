// Jenkins Pipeline for a secure Node.js application deployment to AWS ECS
pipeline {
    agent any

    options {
        // Display timestamps in the console output
        timestamps()
    }

    // Define configurable parameters for the pipeline
    parameters {
        string(name: 'AWS_REGION', defaultValue: 'eu-central-1', description: 'AWS region for ECR/ECS')
        string(name: 'AWS_ACCOUNT_ID', defaultValue: '615299752577', description: 'AWS account ID hosting ECR/ECS')
        string(name: 'ECR_REPOSITORY', defaultValue: 'cicd-node-app', description: 'ECR repository name')
        string(name: 'ECS_CLUSTER', defaultValue: 'cicd-node-cluster', description: 'ECS cluster name')
        string(name: 'ECS_SERVICE', defaultValue: 'cicd-node-service', description: 'ECS service name')
        string(name: 'ECS_TASK_FAMILY', defaultValue: 'cicd-node-app', description: 'ECS task definition family')
        string(name: 'ECS_EXECUTION_ROLE_ARN', defaultValue: 'arn:aws:iam::615299752577:role/cicd-pipeline-dev-ecs-exec-role', description: 'ECS task execution role ARN')
        string(name: 'ECS_TASK_ROLE_ARN', defaultValue: 'arn:aws:iam::615299752577:role/cicd-pipeline-dev-ecs-task-role', description: 'ECS task role ARN')
        string(name: 'CLOUDWATCH_LOG_GROUP', defaultValue: '/ecs/cicd-node-app', description: 'CloudWatch log group for ECS container logs')
        booleanParam(name: 'ENABLE_SONARQUBE', defaultValue: true, description: 'Run SonarQube analysis and quality gate (requires Jenkins SonarQube plugin/config)')
        string(name: 'SONARQUBE_SERVER', defaultValue: 'sonarqube', description: 'Jenkins SonarQube server configuration name')
        string(name: 'GITLEAKS_IMAGE', defaultValue: 'ghcr.io/gitleaks/gitleaks:latest', description: 'Container image used for secret scanning')
        choice(name: 'DEPLOYMENT_STRATEGY', choices: ['rolling'], description: 'Deployment strategy (rolling implemented in this pipeline)')
        booleanParam(name: 'APPLY_ECR_LIFECYCLE_POLICY', defaultValue: true, description: 'Apply ecs/ecr-lifecycle-policy.json to ECR')
        string(name: 'KEEP_ECS_REVISIONS', defaultValue: '10', description: 'Number of ECS task definition revisions to keep active')
    }

    // Define global environment variables used across stages
    environment {
        APP_NAME = 'cicd-node-app'
        REPORT_DIR = 'reports'
        SAST_DIR = 'reports/sast'
        SCA_DIR = 'reports/sca'
        IMAGE_DIR = 'reports/image'
        SECRET_DIR = 'reports/secret'
        SBOM_DIR = 'reports/sbom'
        DEPLOY_DIR = 'reports/deploy'
        // Note: BUILD_TAG_VERSION, IMAGE_URI, ECR_URI, and SHORT_SHA are now initialized dynamically in the Build Metadata stage
        // to avoid conflicts with Declarative Pipeline environment immutability issues.
    }

    stages {
        // Step 1: Clone source code from the repository
        stage('Checkout') {
            steps {
                checkout scm
                // Create report directories if they don't exist
                sh 'mkdir -p ${SAST_DIR} ${SCA_DIR} ${IMAGE_DIR} ${SECRET_DIR} ${SBOM_DIR} ${DEPLOY_DIR}'
            }
        }

        // Step 2: Ensure required AWS parameters are provided
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

        // Step 3: Generate build versioning metadata
        stage('Build Metadata') {
            steps {
                script {
                    // Extract short Git SHA for unique image tagging
                    env.SHORT_SHA = sh(script: 'git rev-parse --short=8 HEAD || echo localdev', returnStdout: true).trim()
                    env.BUILD_TAG_VERSION = "build-${env.BUILD_NUMBER}-${env.SHORT_SHA}"
                    env.ECR_URI = "${params.AWS_ACCOUNT_ID}.dkr.ecr.${params.AWS_REGION}.amazonaws.com/${params.ECR_REPOSITORY}"
                    env.IMAGE_URI = "${env.ECR_URI}:${env.BUILD_TAG_VERSION}"
                    env.GITLEAKS_IMAGE_REF = params.GITLEAKS_IMAGE?.trim() ? params.GITLEAKS_IMAGE.trim() : 'ghcr.io/gitleaks/gitleaks:latest'
                    // Docker CLI talks to host daemon; convert Jenkins-in-container workspace path to host path.
                    env.HOST_WORKSPACE = env.WORKSPACE.startsWith('/var/jenkins_home/') ?
                        env.WORKSPACE.replaceFirst('^/var/jenkins_home/', '/opt/jenkins_home/') :
                        env.WORKSPACE
                }
            }
        }

        // Step 3.1: Lint the Dockerfile for best practices
        stage('Lint Dockerfile') {
            steps {
                sh 'docker run --rm -i hadolint/hadolint < Dockerfile'
            }
        }

        // Step 3.2: Lint shell scripts for common errors
        stage('Lint Scripts') {
            steps {
                sh 'docker run --rm -v "${HOST_WORKSPACE}:/mnt" -w /mnt koalaman/shellcheck:latest scripts/*.sh'
            }
        }

        // Step 4: Install application dependencies
        stage('Install') {
            steps {
                sh '''
                  docker run --rm -v "${HOST_WORKSPACE}:/work" -w /work node:20-alpine \
                    sh -lc "npm ci"
                '''
            }
        }

        // Step 5: Execute unit tests and collect coverage reports
        stage('Unit Tests') {
            steps {
                sh '''
                  docker run --rm -v "${HOST_WORKSPACE}:/work" -w /work node:20-alpine \
                    sh -lc "npm test -- --coverage"
                '''
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'test-results/*.xml'
                    archiveArtifacts allowEmptyArchive: true, artifacts: 'coverage/**'
                }
            }
        }

        // Step 6: Static Application Security Testing (SAST) with SonarQube
        stage('SAST - SonarQube') {
            when {
                expression { return params.ENABLE_SONARQUBE }
            }
            steps {
                withSonarQubeEnv("${params.SONARQUBE_SERVER}") {
                    sh '''
                      # 1. Clean up and prepare workspace for metadata
                      rm -rf .scannerwork
                      mkdir -p .scannerwork
                      chmod 777 .scannerwork

                      # 2. Run the scanner
                      # We pass both SONAR_TOKEN and SONAR_AUTH_TOKEN for compatibility
                      # We also explicitly set the project version and ensure output is visible
                      docker run --rm \
                        --user "$(id -u):$(id -g)" \
                        -e SONAR_HOST_URL="https://sonarcloud.io" \
                        -e SONAR_TOKEN="${SONAR_AUTH_TOKEN}" \
                        -e SONAR_AUTH_TOKEN="${SONAR_AUTH_TOKEN}" \
                        -v "${HOST_WORKSPACE}:/usr/src" \
                        -w /usr/src \
                        sonarsource/sonar-scanner-cli:latest \
                        -Dsonar.projectVersion=${BUILD_TAG_VERSION} \
                        -Dsonar.working.directory=.scannerwork

                      # 3. Verify metadata was generated (helps debugging)
                      if [ -f .scannerwork/report-task.txt ]; then
                          echo "✅ SonarScanner metadata generated successfully."
                          cat .scannerwork/report-task.txt
                      else
                          echo "❌ ERROR: report-task.txt NOT found in .scannerwork/"
                          ls -la .scannerwork/ || true
                          exit 3
                      fi
                    '''
                }
            }
        }

        // Step 7: Wait for SonarQube quality gate analysis
        stage('SAST Quality Gate') {
            when {
                expression { return params.ENABLE_SONARQUBE }
            }
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        // Step 8: Scan for accidentally committed secrets using Gitleaks
        stage('Secret Scan - Gitleaks') {
            steps {
                sh '''
                  docker run --rm -v "${HOST_WORKSPACE}:/repo" "${GITLEAKS_IMAGE_REF}" detect \
                    --source /repo \
                    --report-format json \
                    --report-path /repo/${SECRET_DIR}/gitleaks-report.json \
                    --exit-code 0
                '''
            }
        }

        // Step 9: Software Composition Analysis (SCA) with OWASP Dependency-Check
        stage('SCA - OWASP Dependency-Check') {
            steps {
                script {
                    // 1. Identify if the 'ben' key is available
                    def nvdKey = null
                    try {
                        withCredentials([string(credentialsId: 'ben', variable: 'KEY')]) { nvdKey = KEY }
                        echo "NVD API Key 'ben' verified (Secret Text)."
                    } catch (Exception e) {
                        try {
                            withCredentials([usernamePassword(credentialsId: 'ben', usernameVariable: 'U', passwordVariable: 'P')]) { nvdKey = P }
                            echo "NVD API Key 'ben' verified (Password type)."
                        } catch (Exception e2) {
                            echo "Warning: NVD Key 'ben' not found. Downloads will be very slow."
                        }
                    }

                    // 2. Clear locks and prepare directories
                    sh """
                        mkdir -p /var/jenkins_home/nvd-cache ${env.SCA_DIR}
                        chmod -R 777 /var/jenkins_home/nvd-cache ${env.SCA_DIR}
                        echo "Clearing stale ODC locks..."
                        rm -f /var/jenkins_home/nvd-cache/*.lock.db
                    """

                    // 3. Execute the scan with optimized targeting (just manifests)
                    // This dramatically improves stability and avoids memory/report generation errors
                    // JAVA_OPTS is increased to 2GB to handle large dependency graphs
                    def apiFlag = nvdKey ? "--nvdApiKey '${nvdKey}'" : ""
                    sh """
                        docker run --rm \
                          --user root \
                          -e JAVA_OPTS="-Xmx2g" \
                          -v "${env.HOST_WORKSPACE}:/work" \
                          -v "/opt/jenkins_home/nvd-cache:/usr/share/dependency-check/data" \
                          owasp/dependency-check:latest \
                          --scan /work/package.json \
                          --scan /work/package-lock.json \
                          --project "${env.APP_NAME}" \
                          --format JSON \
                          --out /work/${env.SCA_DIR} \
                          ${apiFlag}
                    """
                }
            }
        }

        // Step 10: Generate Software Bill of Materials (SBOM) with Syft
        stage('SBOM - Syft') {
            steps {
                sh '''
                  docker run --rm -v "${HOST_WORKSPACE}:/work" anchore/syft:latest dir:/work \
                    -o cyclonedx-json=/work/${SBOM_DIR}/sbom-cyclonedx.json
                '''
            }
        }

        // Step 11: Build the production Docker container image
        stage('Build Container') {
            steps {
                sh '''
                  docker build \
                    --build-arg VERSION=${BUILD_TAG_VERSION} \
                    -t ${APP_NAME}:${BUILD_TAG_VERSION} .
                '''
            }
        }

        // Step 12: Scan the Docker image for OS and package vulnerabilities using Trivy
        stage('Image Scan - Trivy') {
            steps {
                sh '''
                  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
                    -v "${HOST_WORKSPACE}:/work" aquasec/trivy:latest image \
                    --format json \
                    --output /work/${IMAGE_DIR}/trivy-image.json \
                    ${APP_NAME}:${BUILD_TAG_VERSION}
                '''
            }
        }

        // Step 13: Enforce the overall security quality gate
        stage('Security Gate') {
            steps {
                sh '''
                  docker run --rm -v "${HOST_WORKSPACE}:/work" -w /work node:20-alpine \
                    sh -lc "node scripts/security-gate.js"
                '''
            }
        }

        // Step 14: Log in to AWS ECR and push the scanned container image
        stage('ECR Login and Push') {
            steps {
                sh '''
                  docker run --rm --network host amazon/aws-cli ecr describe-repositories --repository-names ${ECR_REPOSITORY} --region ${AWS_REGION} >/dev/null 2>&1 || \
                    docker run --rm --network host amazon/aws-cli ecr create-repository --repository-name ${ECR_REPOSITORY} --region ${AWS_REGION} >/dev/null

                  docker run --rm --network host amazon/aws-cli ecr get-login-password --region ${AWS_REGION} | \
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

        // Step 15: Configure ECR lifecycle policy to manage old images automatically
        stage('Apply ECR Lifecycle') {
            when {
                expression { return params.APPLY_ECR_LIFECYCLE_POLICY }
            }
            steps {
                sh '''
                  docker run --rm --network host -v "${HOST_WORKSPACE}:/work" -w /work amazon/aws-cli ecr put-lifecycle-policy \
                    --repository-name ${ECR_REPOSITORY} \
                    --lifecycle-policy-text file:///work/ecs/ecr-lifecycle-policy.json \
                    --region ${AWS_REGION} > ${DEPLOY_DIR}/ecr-lifecycle-policy.json
                '''
            }
        }

        // Step 16: Render the ECS task definition with the new image URI and configuration
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

        // Step 17: Register the new task definition version in AWS ECS
        stage('Register ECS Task Definition') {
            steps {
                sh '''
                  docker run --rm --network host -v "${HOST_WORKSPACE}:/work" -w /work amazon/aws-cli ecs register-task-definition \
                    --cli-input-json file:///work/${DEPLOY_DIR}/taskdef.rendered.json \
                    --region ${AWS_REGION} \
                    --query 'taskDefinition.taskDefinitionArn' \
                    --output text > ${DEPLOY_DIR}/taskdef-arn.txt
                '''
            }
        }

        // Step 18: Trigger a rolling deployment update to the ECS service
        stage('Deploy to ECS Service') {
            when {
                expression { return params.DEPLOYMENT_STRATEGY == 'rolling' }
            }
            steps {
                sh '''
                  TASK_DEF_ARN=$(cat ${DEPLOY_DIR}/taskdef-arn.txt)

                  docker run --rm --network host amazon/aws-cli ecs update-service \
                    --cluster ${ECS_CLUSTER} \
                    --service ${ECS_SERVICE} \
                    --task-definition "$TASK_DEF_ARN" \
                    --force-new-deployment \
                    --region ${AWS_REGION} > ${DEPLOY_DIR}/ecs-update-service.json

                  docker run --rm --network host amazon/aws-cli ecs wait services-stable \
                    --cluster ${ECS_CLUSTER} \
                    --services ${ECS_SERVICE} \
                    --region ${AWS_REGION}

                  docker run --rm --network host amazon/aws-cli ecs describe-services \
                    --cluster ${ECS_CLUSTER} \
                    --services ${ECS_SERVICE} \
                    --region ${AWS_REGION} > ${DEPLOY_DIR}/ecs-service-status.json
                '''
            }
        }

        // Step 19: Clean up old task definitions to avoid exceeding AWS limits
        stage('Cleanup Old ECS Revisions') {
            steps {
                sh '''
                  docker run --rm --network host -v "${HOST_WORKSPACE}:/work" -w /work --entrypoint /bin/bash amazon/aws-cli \
                    /work/scripts/cleanup-ecs-revisions.sh ${ECS_TASK_FAMILY} ${KEEP_ECS_REVISIONS}
                '''
            }
        }
    }

    // Post-pipeline execution cleanup and notification
    post {
        always {
            // Archive build artifacts and scan reports for audit and debugging
            sh "ls -R reports || true"
            archiveArtifacts allowEmptyArchive: true, artifacts: 'reports/**/*, ecs/*.json, sonar-project.properties'
            // Clean up local Docker images to save disk space on the build agent
            script {
                if (env.IMAGE_URI && env.IMAGE_URI != "pending") {
                    sh '''
                      docker image rm ${APP_NAME}:${BUILD_TAG_VERSION} 2>/dev/null || true
                      docker image rm ${IMAGE_URI} 2>/dev/null || true
                      docker image rm ${ECR_URI}:latest 2>/dev/null || true
                      docker image rm ${ECR_URI}:sha-${SHORT_SHA} 2>/dev/null || true
                    '''
                }
            }
        }
        success {
            echo 'Secure CI/CD pipeline completed and ECS service updated.'
        }
        failure {
            echo 'Pipeline failed. Deployment blocked by quality/security gate or runtime error.'
        }
    }
}

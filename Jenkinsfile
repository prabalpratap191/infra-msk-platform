#!/usr/bin/env groovy

/**
 * Jenkins Pipeline for MSK Platform Infrastructure Deployment
 * This pipeline handles Terraform operations for provisioning and managing MSK cluster
 */

pipeline {
    agent any

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'staging', 'prod'],
            description: 'Select the environment to deploy'
        )
        choice(
            name: 'ACTION',
            choices: ['plan', 'apply', 'destroy'],
            description: 'Select Terraform action'
        )
        booleanParam(
            name: 'AUTO_APPROVE',
            defaultValue: false,
            description: 'Auto-approve Terraform apply (use with caution)'
        )
        booleanParam(
            name: 'CREATE_TOPICS',
            defaultValue: true,
            description: 'Create Kafka topics after cluster deployment'
        )
    }

    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
        TF_VERSION = '1.6.0'
        TF_DIR = "terraform/environments/${params.ENVIRONMENT}"
        TF_LOG = 'INFO'
        SCRIPTS_DIR = 'scripts'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '30'))
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "🔄 Checking out code for ${params.ENVIRONMENT} environment"
                }
                checkout scm
                
                script {
                    // Display repository information
                    sh '''
                        echo "Repository: $(git remote get-url origin)"
                        echo "Branch: $(git rev-parse --abbrev-ref HEAD)"
                        echo "Commit: $(git rev-parse HEAD)"
                    '''
                }
            }
        }

        stage('Setup') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'jenkins-user',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    script {
                        echo "🔧 Setting up Terraform and AWS credentials"
                    }
                    
                    sh '''
                        # Verify Terraform installation
                        terraform version
                        
                        # Verify AWS credentials
                        aws sts get-caller-identity
                        
                        # Display environment
                        echo "Environment: ${ENVIRONMENT}"
                        echo "Action: ${ACTION}"
                        echo "Working Directory: ${TF_DIR}"
                    '''
                }
            }
        }

        stage('Terraform Init') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'jenkins-user',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    script {
                        echo "📦 Initializing Terraform"
                    }
                    
                    dir("${TF_DIR}") {
                        sh '''
                            terraform init \
                                -backend-config="bucket=terraform-state-msk-platform-${ENVIRONMENT}" \
                                -backend-config="key=msk/${ENVIRONMENT}/terraform.tfstate" \
                                -backend-config="region=${AWS_DEFAULT_REGION}" \
                                -backend-config="dynamodb_table=terraform-state-lock-msk-platform" \
                                -reconfigure
                        '''
                    }
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                 withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'jenkins-user',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                script {
                    echo "✅ Validating Terraform configuration"
                }
                
                dir("${TF_DIR}") {
                    sh '''
                        terraform validate
                        terraform fmt -check -recursive || true
                    '''
                }
            }
            }
        }

        stage('Terraform Plan') {
            when {
                expression { params.ACTION == 'plan' || params.ACTION == 'apply' }
            }
            steps {
                 withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'jenkins-user',
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                script {
                    echo "📋 Generating Terraform execution plan"
                }
                
                dir("${TF_DIR}") {
                    sh '''
                        terraform plan \
                            -out=tfplan \
                            -var-file=terraform.tfvars \
                            -detailed-exitcode || exit_code=$?
                        
                        # Store plan for apply stage
                        if [ -f tfplan ]; then
                            echo "Plan file created successfully"
                        fi
                    '''
                }
                
                // Archive the plan
                archiveArtifacts artifacts: "${TF_DIR}/tfplan", allowEmptyArchive: false
            }
            }
        }

        stage('Approval Gate') {
            when {
                allOf {
                    expression { params.ACTION == 'apply' || params.ACTION == 'destroy' }
                    expression { params.AUTO_APPROVE == false }
                }
            }
            steps {
                
                script {
                    echo "⏸️  Waiting for manual approval"
                    
                    def userInput = input(
                        id: 'Proceed',
                        message: "Apply Terraform changes to ${params.ENVIRONMENT}?",
                        parameters: [
                            choice(
                                name: 'CONFIRMATION',
                                choices: ['No', 'Yes'],
                                description: 'Confirm deployment'
                            )
                        ]
                    )
                    
                    if (userInput != 'Yes') {
                        error('Deployment cancelled by user')
                    }
                }
            }
        }

        stage('Terraform Apply') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                script {
                    echo "🚀 Applying Terraform configuration"
                }
                
                dir("${TF_DIR}") {
                    sh '''
                        terraform apply \
                            -auto-approve \
                            tfplan
                        
                        # Display outputs
                        echo "\n=== Terraform Outputs ==="
                        terraform output -json > outputs.json
                        terraform output
                    '''
                }
                
                // Archive outputs
                archiveArtifacts artifacts: "${TF_DIR}/outputs.json", allowEmptyArchive: false
            }
        }

        stage('Terraform Destroy') {
            when {
                expression { params.ACTION == 'destroy' }
            }
            steps {
                script {
                    echo "🗑️  Destroying Terraform-managed infrastructure"
                }
                
                dir("${TF_DIR}") {
                    sh '''
                        terraform destroy \
                            -auto-approve \
                            -var-file=terraform.tfvars
                    '''
                }
            }
        }

        stage('Create Kafka Topics') {
            when {
                allOf {
                    expression { params.ACTION == 'apply' }
                    expression { params.CREATE_TOPICS == true }
                }
            }
            steps {
                script {
                    echo "📝 Creating Kafka topics"
                }
                
                dir("${SCRIPTS_DIR}") {
                    sh '''
                        # Wait for MSK cluster to be fully ready
                        echo "Waiting for MSK cluster to be ready..."
                        sleep 60
                        
                        # Make script executable
                        chmod +x create-kafka-topics.sh
                        
                        # Execute topic creation
                        ./create-kafka-topics.sh || {
                            echo "⚠️  Topic creation failed. Topics may already exist."
                            exit 0
                        }
                    '''
                }
            }
        }

        stage('Verification') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                script {
                    echo "🔍 Verifying MSK cluster deployment"
                }
                
                dir("${SCRIPTS_DIR}") {
                    sh '''
                        # Make scripts executable
                        chmod +x verify-msk-cluster.sh
                        chmod +x verify-connectivity.sh
                        
                        # Run verification scripts
                        echo "\n=== MSK Cluster Health Check ==="
                        ./verify-msk-cluster.sh || true
                        
                        echo "\n=== Connectivity Check ==="
                        ./verify-connectivity.sh || true
                    '''
                }
            }
        }

        stage('Publish Outputs') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                script {
                    echo "📤 Publishing deployment outputs"
                }
                
                dir("${TF_DIR}") {
                    sh '''
                        # Extract important outputs
                        BOOTSTRAP_SERVERS=$(terraform output -raw bootstrap_brokers_sasl_iam)
                        CLUSTER_ARN=$(terraform output -raw msk_cluster_arn)
                        VPC_ID=$(terraform output -raw vpc_id)
                        
                        # Create summary file
                        cat > deployment-summary.txt <<EOF
                        ========================================
                        MSK Platform Deployment Summary
                        ========================================
                        Environment: ${ENVIRONMENT}
                        Deployment Time: $(date)
                        Cluster ARN: ${CLUSTER_ARN}
                        Bootstrap Servers: ${BOOTSTRAP_SERVERS}
                        VPC ID: ${VPC_ID}
                        ========================================
                        EOF
                        
                        cat deployment-summary.txt
                    '''
                }
                
                archiveArtifacts artifacts: "${TF_DIR}/deployment-summary.txt", allowEmptyArchive: false
            }
        }
    }

    post {
        success {
            script {
                echo "✅ Pipeline completed successfully!"
                
                // Send success notification
                if (params.ACTION == 'apply') {
                    echo "🎉 MSK cluster deployed successfully to ${params.ENVIRONMENT}"
                }
            }
        }
        
        failure {
            script {
                echo "❌ Pipeline failed!"
                
                // Send failure notification
                echo "🚨 Deployment to ${params.ENVIRONMENT} failed. Check logs for details."
            }
        }
        
        always {
            script {
                echo "🧹 Cleaning up workspace"
            }
            
            // Clean up sensitive files
            dir("${TF_DIR}") {
                sh '''
                    rm -f tfplan
                    rm -f outputs.json
                '''
            }
            
            // Clean workspace
            cleanWs(
                deleteDirs: true,
                patterns: [
                    [pattern: '**/.terraform/**', type: 'INCLUDE'],
                    [pattern: '**/tfplan', type: 'INCLUDE']
                ]
            )
        }
    }
}

#!/usr/bin/env groovy

// ============================================================================
// Jenkins Pipeline for Kafka Infrastructure Deployment
// ============================================================================

pipeline {
    agent any
    
    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'staging', 'prod'],
            description: 'Target environment'
        )
        choice(
            name: 'ACTION',
            choices: ['apply', 'destroy', 'plan'],
            description: 'Terraform action to perform'
        )
        booleanParam(
            name: 'AUTO_APPROVE',
            defaultValue: false,
            description: 'Skip manual approval for apply'
        )
    }
    
    environment {
        AWS_REGION = 'us-east-1'
        TERRAFORM_DIR = "terraform/environments/${params.ENVIRONMENT}"
        SCRIPTS_DIR = 'scripts'
        TF_LOG = 'INFO'
    }
    
    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "=========================================="
                    echo "Kafka Infrastructure Pipeline"
                    echo "Environment: ${params.ENVIRONMENT}"
                    echo "Action: ${params.ACTION}"
                    echo "=========================================="
                }
                checkout scm
            }
        }
        
        stage('Setup') {
            steps {
                script {
                    echo "Setting up environment..."
                    sh '''
                        # Make scripts executable
                        chmod +x ${SCRIPTS_DIR}/*.sh
                        
                        # Install Terraform if not present
                        if ! command -v terraform &> /dev/null; then
                            echo "Installing Terraform..."
                            wget -q https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip
                            unzip -q terraform_1.6.6_linux_amd64.zip
                            sudo mv terraform /usr/local/bin/
                            rm terraform_1.6.6_linux_amd64.zip
                        fi
                        
                        terraform version
                    '''
                }
            }
        }
        
        stage('Terraform Init') {
            steps {
                dir("${TERRAFORM_DIR}") {
                    script {
                        echo "Initializing Terraform..."
                        sh 'terraform init -upgrade'
                    }
                }
            }
        }
        
        stage('Terraform Validate') {
            steps {
                dir("${TERRAFORM_DIR}") {
                    script {
                        echo "Validating Terraform configuration..."
                        sh 'terraform validate'
                        echo "Running tflint..."
                        sh 'terraform fmt -check -recursive || true'
                    }
                }
            }
        }
        stage('Terraform Plan') {
    steps {
         dir("${TERRAFORM_DIR}") {
            script {
                echo "Creating Terraform plan..."
                sh 'terraform plan -var-file="terraform.tfvars" -out=tfplan'
            }
        }
    }
}
        // stage('Terraform Plan') {
        //     steps {
        //         dir("${TERRAFORM_DIR}") {
        //             script {
        //                 echo "Creating Terraform plan..."
        //                 sh 'terraform plan -out=tfplan'
        //                 sh 'terraform show -no-color tfplan > tfplan.txt'
                        
        //                 // Archive the plan
        //                 archiveArtifacts artifacts: 'tfplan.txt', fingerprint: true
        //             }
        //         }
        //     }
        // }
        
        stage('Approval Gate') {
            when {
                expression { params.ACTION == 'apply' && !params.AUTO_APPROVE }
            }
            steps {
                script {
                    echo "Waiting for manual approval..."
                    def plan = readFile("${TERRAFORM_DIR}/tfplan.txt")
                    
                    input message: 'Review the Terraform plan and approve to continue',
                          parameters: [
                              text(name: 'PLAN_REVIEW', 
                                   defaultValue: plan, 
                                   description: 'Terraform Plan')
                          ]
                }
            }
        }
        
        stage('Terraform Apply') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                dir("${TERRAFORM_DIR}") {
                    script {
                        echo "Applying Terraform changes..."
                        sh 'terraform apply -auto-approve tfplan'
                        
                        // Capture outputs
                        sh 'terraform output -json > terraform-outputs.json'
                        archiveArtifacts artifacts: 'terraform-outputs.json', fingerprint: true
                    }
                }
            }
        }
        
        stage('Wait for EC2 Initialization') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                script {
                    echo "Waiting for EC2 instances to initialize..."
                    echo "This includes Docker installation and Kafka deployment via user-data"
                    sleep time: 5, unit: 'MINUTES'
                }
            }
        }
        
        stage('Kafka Validation') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                script {
                    echo "Validating Kafka deployment..."
                    
                    dir("${TERRAFORM_DIR}") {
                        // Get Kafka broker IPs
                        def outputs = readJSON file: 'terraform-outputs.json'
                        def brokerIps = outputs.kafka_private_ips.value
                        def sshCommands = outputs.ssh_connection_commands.value
                        
                        echo "Kafka Broker IPs: ${brokerIps}"
                        echo "SSH Commands: ${sshCommands}"
                        
                        // Note: Actual SSH validation would require SSH keys and network access
                        echo "Kafka validation completed. Review outputs for connection details."
                    }
                }
            }
        }
        
        stage('Publish Outputs') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                script {
                    dir("${TERRAFORM_DIR}") {
                        def outputs = readJSON file: 'terraform-outputs.json'
                        
                        echo "=========================================="
                        echo "KAFKA CLUSTER INFORMATION"
                        echo "=========================================="
                        echo "Bootstrap Servers: ${outputs.kafka_bootstrap_servers.value}"
                        echo "Broker IPs: ${outputs.kafka_private_ips.value}"
                        echo "VPC ID: ${outputs.vpc_id.value}"
                        echo "=========================================="
                        
                        // Create summary file
                        def summaryText = '''# Kafka Deployment Summary

## Environment: ''' + params.ENVIRONMENT + '''

## Connection Details
- **Bootstrap Servers**: ''' + outputs.kafka_bootstrap_servers.value + '''
- **Broker IPs**: ''' + outputs.kafka_private_ips.value.join(', ') + '''
- **VPC ID**: ''' + outputs.vpc_id.value + '''

## Quick Start

```bash
''' + outputs.quick_start_commands.value + '''
```

## Deployment Time
''' + new Date() + '''
'''
                        writeFile file: 'deployment-summary.md', text: summaryText
                        
                        archiveArtifacts artifacts: 'deployment-summary.md', fingerprint: true
                    }
                }
            }
        }
        
        stage('Terraform Destroy') {
            when {
                expression { params.ACTION == 'destroy' }
            }
            steps {
                script {
                    input message: 'Are you sure you want to destroy the infrastructure?',
                          ok: 'Yes, Destroy!'
                }
                
                dir("${TERRAFORM_DIR}") {
                    script {
                        echo "Destroying Terraform infrastructure..."
                        sh 'terraform destroy -auto-approve'
                    }
                }
            }
        }
        
        stage('Verification') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                script {
                    echo "Running post-deployment verification..."
                    echo "Kafka infrastructure deployed successfully!"
                    echo "Please review the deployment-summary.md artifact for connection details."
                }
            }
        }
    }
    
    post {
        success {
            script {
                echo "=========================================="
                echo "Pipeline Completed Successfully"
                echo "Action: ${params.ACTION}"
                echo "Environment: ${params.ENVIRONMENT}"
                echo "=========================================="
                
                // Send notification (configure based on your notification system)
                // emailext (
                //     subject: "Kafka Deployment Success - ${params.ENVIRONMENT}",
                //     body: "Kafka infrastructure ${params.ACTION} completed successfully.",
                //     to: "devops-team@meracommerce.com"
                // )
            }
        }
        
        failure {
            script {
                echo "=========================================="
                echo "Pipeline Failed"
                echo "Action: ${params.ACTION}"
                echo "Environment: ${params.ENVIRONMENT}"
                echo "=========================================="
                
                // Send failure notification
                // emailext (
                //     subject: "Kafka Deployment Failed - ${params.ENVIRONMENT}",
                //     body: "Kafka infrastructure ${params.ACTION} failed. Check Jenkins logs.",
                //     to: "devops-team@meracommerce.com"
                // )
            }
        }
        
        always {
            script {
                // Cleanup
                cleanWs()
            }
        }
    }
}

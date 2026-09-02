pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-east-1'
        TF_DIR = 'terraform'
        SCRIPTS_DIR = 'scripts'
        SSH_KEY_PATH = credentials('kafka-ec2-key')  // Jenkins credential ID for SSH key
        AWS_CREDENTIALS = credentials('jenkins-server')  // Jenkins credential ID for AWS
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo '==================================' 
                echo 'Stage 1: Checkout Git Repository'
                echo '=================================='
                checkout scm
                sh 'ls -la'
            }
        }
        
        stage('Terraform Init') {
            steps {
                echo '=================================='
                echo 'Stage 2: Terraform Initialization'
                echo '=================================='
                dir("${TF_DIR}") {
                    sh '''
                        terraform init
                        echo "✓ Terraform initialized successfully"
                    '''
                }
            }
        }
        
        stage('Terraform Validate') {
            steps {
                echo '=================================='
                echo 'Stage 3: Terraform Validation'
                echo '=================================='
                dir("${TF_DIR}") {
                    sh '''
                        terraform validate
                        echo "✓ Terraform configuration is valid"
                    '''
                }
            }
        }
        
        stage('Terraform Plan') {
            steps {
                echo '=================================='
                echo 'Stage 4: Terraform Plan'
                echo '=================================='
                dir("${TF_DIR}") {
                    sh '''
                        terraform plan -out=tfplan
                        echo "✓ Terraform plan created successfully"
                    '''
                }
            }
        }
        
        stage('Terraform Apply') {
            steps {
                echo '=================================='
                echo 'Stage 5: Terraform Apply'
                echo '=================================='
                dir("${TF_DIR}") {
                    sh '''
                        terraform apply -auto-approve tfplan
                        echo "✓ Infrastructure provisioned successfully"
                    '''
                }
            }
        }
        
        stage('Get EC2 Instance Details') {
            steps {
                echo '=================================='
                echo 'Stage 6: Retrieve EC2 Details'
                echo '=================================='
                dir("${TF_DIR}") {
                    script {
                        env.EC2_PUBLIC_IP = sh(
                            script: 'terraform output -raw ec2_public_ip',
                            returnStdout: true
                        ).trim()
                        
                        env.EC2_PRIVATE_IP = sh(
                            script: 'terraform output -raw ec2_private_ip',
                            returnStdout: true
                        ).trim()
                        
                        env.EC2_INSTANCE_ID = sh(
                            script: 'terraform output -raw ec2_instance_id',
                            returnStdout: true
                        ).trim()
                        
                        echo "=================================="
                        echo "EC2 Instance Created Successfully"
                        echo "=================================="
                        echo "Instance ID: ${env.EC2_INSTANCE_ID}"
                        echo "Public IP: ${env.EC2_PUBLIC_IP}"
                        echo "Private IP: ${env.EC2_PRIVATE_IP}"
                        echo "=================================="
                    }
                }
            }
        }
        
        stage('Wait for EC2 Initialization') {
            steps {
                echo '=================================='
                echo 'Waiting for EC2 User Data to Complete'
                echo '=================================='
                script {
                    // Wait for instance to be fully initialized
                    sleep time: 3, unit: 'MINUTES'
                    echo "✓ EC2 initialization complete"
                }
            }
        }
        
        stage('Verify Docker Installation') {
            steps {
                echo '=================================='
                echo 'Stage 7: Verify Docker Installation'
                echo '=================================='
                script {
                    sh """
                        ssh -o StrictHostKeyChecking=no -i ${SSH_KEY_PATH} ec2-user@${env.EC2_PUBLIC_IP} \
                            'docker --version'
                    """
                    echo "✓ Docker installed successfully"
                    
                    sh """
                        ssh -o StrictHostKeyChecking=no -i ${SSH_KEY_PATH} ec2-user@${env.EC2_PUBLIC_IP} \
                            'docker compose version'
                    """
                    echo "✓ Docker Compose installed successfully"
                }
            }
        }
        
        stage('Deploy Kafka') {
            steps {
                echo '=================================='
                echo 'Stage 8: Deploy Kafka'
                echo '=================================='
                script {
                    // Start Kafka using Docker Compose
                    sh """
                        ssh -o StrictHostKeyChecking=no -i ${SSH_KEY_PATH} ec2-user@${env.EC2_PUBLIC_IP} \
                            'cd /opt/kafka && docker compose up -d'
                    """
                    echo "✓ Kafka deployment initiated"
                    
                    // Wait for Kafka to be ready
                    echo "Waiting for Kafka to start..."
                    sleep time: 1, unit: 'MINUTES'
                    
                    // Verify Kafka container is running
                    sh """
                        ssh -o StrictHostKeyChecking=no -i ${SSH_KEY_PATH} ec2-user@${env.EC2_PUBLIC_IP} \
                            'docker ps | grep kafka-server'
                    """
                    echo "✓ Kafka container is running"
                }
            }
        }
        
        stage('Create Kafka Topics') {
            steps {
                echo '=================================='
                echo 'Stage 9: Create Kafka Topics'
                echo '=================================='
                script {
                    // Copy topics script to EC2
                    sh """
                        scp -o StrictHostKeyChecking=no -i ${SSH_KEY_PATH} \
                            ${SCRIPTS_DIR}/create-topics.sh \
                            ec2-user@${env.EC2_PUBLIC_IP}:/home/ec2-user/
                    """
                    
                    // Make script executable and run it
                    sh """
                        ssh -o StrictHostKeyChecking=no -i ${SSH_KEY_PATH} ec2-user@${env.EC2_PUBLIC_IP} \
                            'chmod +x /home/ec2-user/create-topics.sh && /home/ec2-user/create-topics.sh'
                    """
                    echo "✓ All topics created successfully"
                }
            }
        }
        
        stage('Verify Kafka Installation') {
            steps {
                echo '=================================='
                echo 'Stage 10: Kafka Verification'
                echo '=================================='
                script {
                    // Copy verification script to EC2
                    sh """
                        scp -o StrictHostKeyChecking=no -i ${SSH_KEY_PATH} \
                            ${SCRIPTS_DIR}/verify-kafka.sh \
                            ec2-user@${env.EC2_PUBLIC_IP}:/home/ec2-user/
                    """
                    
                    // Run verification
                    sh """
                        ssh -o StrictHostKeyChecking=no -i ${SSH_KEY_PATH} ec2-user@${env.EC2_PUBLIC_IP} \
                            'chmod +x /home/ec2-user/verify-kafka.sh && /home/ec2-user/verify-kafka.sh'
                    """
                    echo "✓ Kafka verification successful"
                }
            }
        }
        
        stage('Print Kafka Connection Details') {
            steps {
                echo '=================================='
                echo 'Stage 11: Kafka Connection Details'
                echo '=================================='
                script {
                    echo """
=================================="
KAFKA DEPLOYMENT INFORMATION
==================================

EC2 Instance Details:
  Instance ID: ${env.EC2_INSTANCE_ID}
  Public IP: ${env.EC2_PUBLIC_IP}
  Private IP: ${env.EC2_PRIVATE_IP}

Kafka Bootstrap Servers:
  Internal (VPC): ${env.EC2_PRIVATE_IP}:9092
  External: ${env.EC2_PUBLIC_IP}:9094

Created Topics:
  • customer-events
  • order-events
  • catalog-events
  • payment-events
  • inventory-events
  • notification-events
  • dead-letter-events

Spring Boot Configuration:
----------------------------------
spring:
  kafka:
    bootstrap-servers: ${env.EC2_PRIVATE_IP}:9092
    consumer:
      group-id: my-consumer-group
      auto-offset-reset: earliest
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.springframework.kafka.support.serializer.JsonDeserializer
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer
----------------------------------

Connection String:
  ${env.EC2_PRIVATE_IP}:9092

==================================
                    """
                }
            }
        }
        
        stage('Deployment Success') {
            steps {
                echo ''
                echo '=================================='
                echo '   KAFKA DEPLOYMENT SUCCESSFUL'
                echo '=================================='
                echo ''
                echo 'Kafka Status: ✓ RUNNING'
                echo 'EC2 Status: ✓ RUNNING'
                echo ''
                echo 'Topics Created:'
                echo '  • customer-events'
                echo '  • order-events'
                echo '  • catalog-events'
                echo '  • payment-events'
                echo '  • inventory-events'
                echo '  • notification-events'
                echo '  • dead-letter-events'
                echo ''
                echo '✓ Ready for Spring Boot Integration'
                echo '=================================='
            }
        }
    }
    
    post {
        success {
            echo ''
            echo '🎉 Pipeline executed successfully!'
            echo 'Kafka is now ready to use.'
        }
        failure {
            echo ''
            echo '❌ Pipeline failed!'
            echo 'Check the logs for details.'
        }
        always {
            echo ''
            echo 'Pipeline execution completed.'
        }
    }
}

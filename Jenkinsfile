pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-east-1'
        TF_DIR = 'terraform'
        SCRIPTS_DIR = 'scripts'
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
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', 
                                      credentialsId: 'jenkins-user']]) {
                        sh '''
                            terraform init
                            echo "✓ Terraform initialized successfully"
                        '''
                    }
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
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', 
                                      credentialsId: 'jenkins-user']]) {
                        sh '''
                            terraform plan -var-file=terraform.tfvars -out=tfplan
                            echo "✓ Terraform plan created successfully"
                        '''
                    }
                }
            }
        }
        
        stage('Terraform Apply') {
            steps {
                echo '=================================='
                echo 'Stage 5: Terraform Apply'
                echo '=================================='
                dir("${TF_DIR}") {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', 
                                      credentialsId: 'jenkins-user']]) {
                        sh '''
                            terraform apply -auto-approve tfplan
                            echo "✓ Infrastructure provisioned successfully"
                            echo "✓ SSH key pair created dynamically"
                        '''
                    }
                }
            }
        }
        
        stage('Get EC2 Instance Details') {
            steps {
                echo '=================================='
                echo 'Stage 6: Retrieve EC2 Details & SSH Key'
                echo '=================================='
                dir("${TF_DIR}") {
                    script {
                         env.EC2_PUBLIC_IP = sh(
                            script: 'terraform output -raw public_ip',
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
                        
                        env.SSH_KEY_NAME = sh(
                            script: 'terraform output -raw ssh_key_name',
                            returnStdout: true
                        ).trim()
                        
                        echo "=================================="
                        echo "EC2 Instance Created Successfully"
                        echo "=================================="
                        echo "Instance ID: ${env.EC2_INSTANCE_ID}"
                        echo "Public IP: ${env.EC2_PUBLIC_IP}"
                        echo "Private IP: ${env.EC2_PRIVATE_IP}"
                        echo "SSH Key: ${env.SSH_KEY_NAME}"
                        echo "=================================="
                    }
                }
            }
        }
        
        stage('Wait for EC2 Initialization') {
            steps {
                echo '=================================='
                echo 'Waiting for EC2 to Complete Initialization'
                echo '=================================='
                script {
                    echo "Waiting for instance to be fully ready..."
                    sleep time: 3, unit: 'MINUTES'
                    
                    // Wait for SSH to be available
                    echo "Testing SSH connectivity..."
                    dir("${TF_DIR}") {
                        retry(10) {
                            sh """
                                ssh -o StrictHostKeyChecking=no \
                                    -o ConnectTimeout=5 \
                                    -i kafka-ec2-private-key.pem \
                                    ec2-user@${env.EC2_PUBLIC_IP} 'echo "SSH connection successful"'
                            """
                            sleep 10
                        }
                    }
                    echo "✓ EC2 instance is ready and SSH is available"
                }
            }
        }
        
        stage('Install Docker') {
            steps {
                echo '=================================='
                echo 'Stage 7: Install Docker & Docker Compose'
                echo '=================================='
                script {
                    dir("${TF_DIR}") {
                        // Copy installation script to EC2
                        sh """
                            scp -o StrictHostKeyChecking=no \
                                -i kafka-ec2-private-key.pem \
                                ../install-docker.sh \
                                ec2-user@${env.EC2_PUBLIC_IP}:/home/ec2-user/
                        """
                        
                        // Execute installation script
                        sh """
                            ssh -o StrictHostKeyChecking=no \
                                -i kafka-ec2-private-key.pem \
                                ec2-user@${env.EC2_PUBLIC_IP} \
                                'chmod +x /home/ec2-user/install-docker.sh && /home/ec2-user/install-docker.sh'
                        """
                        echo "✓ Docker installed successfully"
                    }
                }
            }
        }
        
        stage('Verify Docker Installation') {
            steps {
                echo '=================================='
                echo 'Stage 8: Verify Docker Installation'
                echo '=================================='
                script {
                    dir("${TF_DIR}") {
                        sh """
                            ssh -o StrictHostKeyChecking=no \
                                -i kafka-ec2-private-key.pem \
                                ec2-user@${env.EC2_PUBLIC_IP} \
                                'sudo docker --version'
                        """
                        echo "✓ Docker verified"
                        
                        sh """
                            ssh -o StrictHostKeyChecking=no \
                                -i kafka-ec2-private-key.pem \
                                ec2-user@${env.EC2_PUBLIC_IP} \
                                'sudo docker compose version'
                        """
                        echo "✓ Docker Compose verified"
                    }
                }
            }
        }
        
        stage('Setup Kafka') {
            steps {
                echo '=================================='
                echo 'Stage 9: Setup Kafka Configuration'
                echo '=================================='
                script {
                    dir("${TF_DIR}") {
                        // Copy Kafka setup script to EC2
                        sh """
                            scp -o StrictHostKeyChecking=no \
                                -i kafka-ec2-private-key.pem \
                                ../setup-kafka.sh \
                                ec2-user@${env.EC2_PUBLIC_IP}:/home/ec2-user/
                        """
                        
                        // Execute Kafka setup script with parameters
                        sh """
                            ssh -o StrictHostKeyChecking=no \
                                -i kafka-ec2-private-key.pem \
                                ec2-user@${env.EC2_PUBLIC_IP} \
                                'chmod +x /home/ec2-user/setup-kafka.sh && /home/ec2-user/setup-kafka.sh ${env.EC2_PRIVATE_IP} ${env.EC2_PUBLIC_IP} 1 kafka-cluster-dev'
                        """
                        echo "✓ Kafka configuration created"
                    }
                }
            }
        }
        
        stage('Wait for Kafka Startup') {
            steps {
                echo '=================================='
                echo 'Waiting for Kafka to Start'
                echo '=================================='
                script {
                    echo "Waiting for Kafka to initialize..."
                    sleep time: 2, unit: 'MINUTES'
                    
                    // Verify Kafka container is running
                    dir("${TF_DIR}") {
                        sh """
                            ssh -o StrictHostKeyChecking=no \
                                -i kafka-ec2-private-key.pem \
                                ec2-user@${env.EC2_PUBLIC_IP} \
                                'sudo docker ps | grep kafka-server'
                        """
                    }
                    echo "✓ Kafka container is running"
                }
            }
        }
        
        stage('Create Kafka Topics') {
            steps {
                echo '=================================='
                echo 'Stage 10: Create Kafka Topics'
                echo '=================================='
                script {
                    dir("${TF_DIR}") {
                        // Copy topics script to EC2
                        sh """
                            scp -o StrictHostKeyChecking=no \
                                -i kafka-ec2-private-key.pem \
                                ../scripts/create-topics.sh \
                                ec2-user@${env.EC2_PUBLIC_IP}:/home/ec2-user/
                        """
                        
                        // Make script executable and run it
                        sh """
                            ssh -o StrictHostKeyChecking=no \
                                -i kafka-ec2-private-key.pem \
                                ec2-user@${env.EC2_PUBLIC_IP} \
                                'chmod +x /home/ec2-user/create-topics.sh && /home/ec2-user/create-topics.sh'
                        """
                        echo "✓ All topics created successfully"
                    }
                }
            }
        }
        
        stage('Verify Kafka Installation') {
            steps {
                echo '=================================='
                echo 'Stage 11: Kafka Verification'
                echo '=================================='
                script {
                    dir("${TF_DIR}") {
                        // Copy verification script to EC2
                        sh """
                            scp -o StrictHostKeyChecking=no \
                                -i kafka-ec2-private-key.pem \
                                ../scripts/verify-kafka.sh \
                                ec2-user@${env.EC2_PUBLIC_IP}:/home/ec2-user/
                        """
                        
                        // Run verification
                        sh """
                            ssh -o StrictHostKeyChecking=no \
                                -i kafka-ec2-private-key.pem \
                                ec2-user@${env.EC2_PUBLIC_IP} \
                                'chmod +x /home/ec2-user/verify-kafka.sh && /home/ec2-user/verify-kafka.sh'
                        """
                        echo "✓ Kafka verification successful"
                    }
                }
            }
        }
        
        stage('Print Kafka Connection Details') {
            steps {
                echo '=================================='
                echo 'Stage 12: Kafka Connection Details'
                echo '=================================='
                script {
                    dir("${TF_DIR}") {
                        def sshCommand = sh(
                            script: 'terraform output -raw ssh_connection_command',
                            returnStdout: true
                        ).trim()
                        
                        echo """
==================================
KAFKA DEPLOYMENT INFORMATION
==================================

EC2 Instance Details:
  Instance ID: ${env.EC2_INSTANCE_ID}
  Public IP: ${env.EC2_PUBLIC_IP}
  Private IP: ${env.EC2_PRIVATE_IP}
  SSH Key: ${env.SSH_KEY_NAME}

SSH Access:
  cd terraform
  ${sshCommand}

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
                echo 'SSH Key: ✓ DYNAMICALLY GENERATED'
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
            echo ''
            echo 'SSH Key Location: terraform/kafka-ec2-private-key.pem'
            echo 'To connect: cd terraform && ssh -i kafka-ec2-private-key.pem ec2-user@' + env.EC2_PUBLIC_IP
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

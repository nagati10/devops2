pipeline {
    agent any
    
    tools {
        maven 'M2_HOME'
        jdk 'JDK11'
    }

    environment {
        DOCKER_IMAGE = 'najdnagati/student-management'
        DOCKER_TAG = "${env.BUILD_NUMBER}"
        K8S_NAMESPACE = 'devops'
        SONARQUBE_URL = 'http://localhost:9000'
        SPRING_BOOT_URL = 'http://localhost:30080'
    }

    stages {
        stage('Clean Workspace') {
            steps {
                cleanWs()
                echo "✅ Workspace cleaned for build #${env.BUILD_NUMBER}"
            }
        }

        stage('Checkout Code') {
            steps {
                // Use main branch, not master
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: '*/main']],
                    extensions: [],
                    userRemoteConfigs: [[
                        url: 'https://github.com/nagati10/devops2.git'
                    ]]
                ])
                
                echo "✅ Code fetched from GitHub (main branch)"
                
                sh '''
                    echo "=== Repository Contents ==="
                    pwd
                    ls -la
                    echo ""
                    echo "=== Checking project structure ==="
                    [ -f "pom.xml" ] && echo "✅ pom.xml found" || echo "❌ pom.xml not found"
                    [ -d "src" ] && echo "✅ src directory found" || echo "❌ src directory not found"
                    [ -f "Dockerfile" ] && echo "✅ Dockerfile found" || echo "❌ Dockerfile not found"
                '''
            }
        }

        stage('Setup Environment') {
            steps {
                sh '''
                    echo "=== Environment Setup ==="
                    echo "Java Version:"
                    java -version
                    echo "Maven Version:"
                    mvn --version
                '''
            }
        }

        stage('Build & Test') {
            steps {
                sh '''
                    echo "=== Building Application ==="
                    
                    # Clean first
                    mvn clean
                    
                    # Compile
                    mvn compile
                    
                    echo "✅ Compilation successful"
                    
                    # Run tests
                    mvn test
                    
                    echo "✅ Tests completed"
                    
                    # Generate reports
                    mvn jacoco:report
                    
                    # Show results
                    echo "=== Test Results ==="
                    find target/surefire-reports -name "*.xml" 2>/dev/null | head -3
                    [ -f "target/site/jacoco/jacoco.xml" ] && echo "✅ JaCoCo report generated"
                '''
            }
            
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }

        stage('Package Application') {
            steps {
                sh '''
                    echo "=== Packaging Application ==="
                    
                    # Package without tests
                    mvn package -DskipTests
                    
                    echo "✅ Application packaged"
                    ls -lh target/*.jar
                '''
                
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            }
        }

        stage('Build Docker Image') {
            steps {
                sh """
                    echo "=== Building Docker Image ==="
                    
                    # Check Dockerfile
                    if [ -f "Dockerfile" ]; then
                        echo "✅ Dockerfile found"
                    else
                        echo "❌ Dockerfile not found!"
                        exit 1
                    fi
                    
                    # Build Docker image
                    docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .
                    docker tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_IMAGE}:latest
                    
                    echo "✅ Docker images created:"
                    docker images | grep ${DOCKER_IMAGE}
                """
            }
        }

        stage('Push to DockerHub') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'najdnagati',
                    usernameVariable: 'DOCKER_USERNAME',
                    passwordVariable: 'DOCKER_PASSWORD'
                )]) {
                    sh """
                        echo "=== Pushing to DockerHub ==="
                        
                        # Login to DockerHub
                        echo \${DOCKER_PASSWORD} | docker login -u \${DOCKER_USERNAME} --password-stdin
                        
                        # Push images
                        docker push ${DOCKER_IMAGE}:${DOCKER_TAG}
                        docker push ${DOCKER_IMAGE}:latest
                        
                        echo "✅ Images pushed to DockerHub"
                    """
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                script {
                    // Set kubectl config
                    sh '''
                        echo "=== Deploying to Kubernetes ==="
                        export KUBECONFIG=/var/lib/jenkins/.kube/config
                        
                        # Create namespace if not exists
                        kubectl create namespace ${K8S_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                    '''
                    
                    // Deploy MySQL
                    sh '''
                        echo "=== Deploying MySQL ==="
                        
                        # Deploy MySQL
                        kubectl apply -f mysql-deployment.yaml -n ${K8S_NAMESPACE}
                        
                        # Wait for MySQL
                        echo "Waiting for MySQL..."
                        sleep 30
                        
                        # Check MySQL status
                        kubectl get pods -n ${K8S_NAMESPACE} -l app=mysql
                    '''
                    
                    // Deploy Spring Boot
                    sh """
                        echo "=== Deploying Spring Boot ==="
                        
                        # Update image in deployment file
                        sed -i "s|image:.*najdnagati/student-management.*|image: ${DOCKER_IMAGE}:${DOCKER_TAG}|g" spring-deployment.yaml
                        
                        # Apply deployment
                        kubectl apply -f spring-deployment.yaml -n ${K8S_NAMESPACE}
                        
                        # Wait for rollout
                        echo "Waiting for Spring Boot rollout..."
                        kubectl rollout status deployment/spring-app -n ${K8S_NAMESPACE} --timeout=300s
                        
                        echo "✅ Spring Boot deployed"
                    """
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    echo "=== Verification ==="
                    
                    export KUBECONFIG=/var/lib/jenkins/.kube/config
                    
                    echo "1. Pods Status:"
                    kubectl get pods -n ${K8S_NAMESPACE}
                    
                    echo ""
                    echo "2. Services:"
                    kubectl get svc -n ${K8S_NAMESPACE}
                    
                    echo ""
                    echo "3. Application URL:"
                    minikube service spring-service -n ${K8S_NAMESPACE} --url 2>/dev/null || echo "Getting service URL..."
                '''
            }
        }
    }

    post {
        always {
            echo "=== Build #${env.BUILD_NUMBER} Completed ==="
            
            // Archive artifacts
            archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            archiveArtifacts artifacts: 'target/surefire-reports/*.xml', fingerprint: true
            
            // Cleanup
            sh 'docker system prune -f 2>/dev/null || true'
        }
        
        success {
            echo "🎉🎉🎉 BUILD SUCCESSFUL! 🎉🎉🎉"
            
            script {
                // Get URLs
                sh '''
                    MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "localhost")
                    SPRING_PORT=$(kubectl get svc spring-service -n ${K8S_NAMESPACE} -o jsonpath="{.spec.ports[0].nodePort}" 2>/dev/null || echo "30080")
                    
                    echo ""
                    echo "=== DEPLOYMENT SUMMARY ==="
                    echo "Application URL: http://${MINIKUBE_IP}:${SPRING_PORT}"
                    echo "Docker Image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                    echo "K8S Namespace: ${K8S_NAMESPACE}"
                    echo ""
                '''
            }
        }
        
        failure {
            echo "❌❌❌ BUILD FAILED ❌❌❌"
            
            script {
                // Debug information
                sh '''
                    echo ""
                    echo "=== DEBUG INFORMATION ==="
                    echo "Workspace contents:"
                    pwd
                    ls -la
                    echo ""
                    echo "Maven build status:"
                    ls -la target/ 2>/dev/null || echo "No target directory"
                    echo ""
                    echo "Docker images:"
                    docker images | grep ${DOCKER_IMAGE} 2>/dev/null || echo "No Docker images"
                '''
            }
        }
    }
}
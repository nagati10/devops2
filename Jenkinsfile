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
                // FIXED: Changed from 'master' to 'main'
                git branch: 'main',
                    url: 'https://github.com/nagati10/devops2.git'
                
                echo "✅ Code fetched from GitHub (main branch)"
                
                // Debug: Show what was checked out
                sh '''
                    echo "=== Repository Contents ==="
                    pwd
                    ls -la
                    echo ""
                    echo "=== Git Status ==="
                    git status
                    git branch -a
                    echo ""
                    echo "=== Check pom.xml ==="
                    if [ -f "pom.xml" ]; then
                        echo "✅ pom.xml found"
                        head -10 pom.xml
                    else
                        echo "❌ pom.xml not found!"
                    fi
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
                    echo "Workspace:"
                    pwd
                    ls -la
                '''
            }
        }

        stage('Build & Test') {
            steps {
                sh '''
                    echo "=== Building Application ==="
                    
                    # First, clean
                    mvn clean
                    
                    echo "✅ Clean completed"
                    
                    # Check if we have source code
                    echo "Checking source files:"
                    find src/ -name "*.java" | head -5
                    
                    # Compile
                    mvn compile
                    
                    echo "✅ Compilation successful"
                    
                    # Run tests
                    mvn test
                    
                    echo "✅ Tests completed"
                    
                    # Generate reports
                    mvn jacoco:report
                    
                    echo "✅ Reports generated"
                    
                    # Show what was created
                    echo "Generated files:"
                    ls -la target/ 2>/dev/null || echo "No target directory"
                '''
            }
            
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }

        stage('Code Quality - SonarQube') {
            steps {
                script {
                    // First, make sure SonarQube is deployed
                    sh '''
                        echo "=== Checking SonarQube ==="
                        # Deploy SonarQube if not already deployed
                        kubectl apply -f sonarqube-deployment.yaml -n ${K8S_NAMESPACE} 2>/dev/null || true
                        
                        # Wait for SonarQube to be ready
                        echo "Waiting for SonarQube..."
                        sleep 30
                    '''
                    
                    // Run SonarQube analysis
                    withSonarQubeEnv('sonarqube') {
                        sh '''
                            echo "=== Running SonarQube Analysis ==="
                            
                            # Check if JaCoCo report exists
                            if [ -f "target/site/jacoco/jacoco.xml" ]; then
                                echo "✅ JaCoCo report found"
                            else
                                echo "⚠️ Generating JaCoCo report..."
                                mvn jacoco:report
                            fi
                            
                            # Run SonarQube scan
                            mvn sonar:sonar \
                                -Dsonar.projectKey=student-management \
                                -Dsonar.projectName="Student Management System" \
                                -Dsonar.host.url=${SONARQUBE_URL} \
                                -Dsonar.login=admin \
                                -Dsonar.password=admin \
                                -Dsonar.java.binaries=target/classes \
                                -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml
                            
                            echo "✅ SonarQube analysis completed"
                        '''
                    }
                }
            }
        }

        stage('Package Application') {
            steps {
                sh '''
                    echo "=== Packaging Application ==="
                    
                    # Package without running tests again
                    mvn package -DskipTests
                    
                    echo "✅ Application packaged"
                    ls -lh target/*.jar
                '''
                
                // Archive the JAR
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
                        cat Dockerfile
                    else
                        echo "❌ Dockerfile not found!"
                        exit 1
                    fi
                    
                    # Build Docker image
                    docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .
                    docker tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_IMAGE}:latest
                    
                    echo "✅ Docker images created"
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
                        echo \$DOCKER_PASSWORD | docker login -u \$DOCKER_USERNAME --password-stdin
                        
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
                    sh '''
                        echo "=== Deploying to Kubernetes ==="
                        
                        # Set kubectl config
                        export KUBECONFIG=/var/lib/jenkins/.kube/config
                        
                        # Create namespace if not exists
                        kubectl create namespace ${K8S_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                        
                        echo "✅ Namespace ready"
                    '''
                    
                    // Deploy MySQL
                    sh '''
                        echo "=== Deploying MySQL ==="
                        
                        # Check if MySQL is already deployed
                        if ! kubectl get deployment mysql -n ${K8S_NAMESPACE} 2>/dev/null; then
                            echo "Deploying MySQL..."
                            kubectl apply -f mysql-deployment.yaml -n ${K8S_NAMESPACE}
                            
                            # Wait for MySQL to be ready
                            echo "Waiting for MySQL to be ready..."
                            sleep 45
                            
                            # Check MySQL logs
                            MYSQL_POD=$(kubectl get pods -n ${K8S_NAMESPACE} -l app=mysql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
                            if [ -n "$MYSQL_POD" ]; then
                                echo "MySQL pod: $MYSQL_POD"
                                kubectl logs $MYSQL_POD -n ${K8S_NAMESPACE} --tail=5
                            fi
                        else
                            echo "✅ MySQL already deployed"
                        fi
                    '''
                    
                    // Deploy Spring Boot
                    sh """
                        echo "=== Deploying Spring Boot ==="
                        
                        # Update the image in deployment file
                        sed -i "s|image:.*najdnagati/student-management.*|image: ${DOCKER_IMAGE}:${DOCKER_TAG}|g" spring-deployment.yaml
                        
                        # Apply deployment
                        kubectl apply -f spring-deployment.yaml -n ${K8S_NAMESPACE}
                        
                        # Wait for rollout
                        echo "⏳ Waiting for Spring Boot rollout..."
                        kubectl rollout status deployment/spring-app -n ${K8S_NAMESPACE} --timeout=300s
                        
                        echo "✅ Spring Boot deployed with image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                    '''
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    echo "=== Verification ==="
                    
                    export KUBECONFIG=/var/lib/jenkins/.kube/config
                    
                    echo "1. Pods Status:"
                    kubectl get pods -n ${K8S_NAMESPACE} -o wide
                    
                    echo ""
                    echo "2. Services:"
                    kubectl get svc -n ${K8S_NAMESPACE}
                    
                    echo ""
                    echo "3. Spring Boot Logs:"
                    SPRING_POD=$(kubectl get pods -n ${K8S_NAMESPACE} -l app=spring-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
                    if [ -n "$SPRING_POD" ]; then
                        echo "Spring Boot pod: $SPRING_POD"
                        kubectl logs $SPRING_POD -n ${K8S_NAMESPACE} --tail=20
                    else
                        echo "❌ No Spring Boot pod found"
                    fi
                    
                    echo ""
                    echo "4. Application URL:"
                    minikube service spring-service -n ${K8S_NAMESPACE} --url 2>/dev/null || echo "Service not ready yet"
                    
                    echo "✅ Verification complete"
                '''
            }
        }

        stage('Deploy Monitoring Stack') {
            steps {
                script {
                    sh '''
                        echo "=== Deploying Monitoring Stack ==="
                        
                        # Deploy SonarQube
                        kubectl apply -f sonarqube-deployment.yaml -n ${K8S_NAMESPACE} 2>/dev/null || true
                        
                        # Deploy Prometheus
                        kubectl apply -f prometheus-deployment.yaml -n ${K8S_NAMESPACE} 2>/dev/null || true
                        
                        # Deploy Grafana
                        kubectl apply -f grafana-deployment.yaml -n ${K8S_NAMESPACE} 2>/dev/null || true
                        
                        echo "✅ Monitoring stack deployed"
                        
                        # Show monitoring URLs
                        echo ""
                        echo "📊 Monitoring URLs:"
                        echo "- SonarQube: http://$(minikube ip):$(kubectl get svc sonarqube-service -n ${K8S_NAMESPACE} -o jsonpath='{.spec.ports[0].nodePort}')"
                        echo "- Prometheus: http://$(minikube ip):30091"
                        echo "- Grafana: http://$(minikube ip):30092"
                    '''
                }
            }
        }
    }

    post {
        always {
            echo "=== Build #${env.BUILD_NUMBER} Completed ==="
            
            // Archive reports
            archiveArtifacts artifacts: 'target/surefire-reports/*.xml', fingerprint: true
            archiveArtifacts artifacts: 'target/site/jacoco/*.*', fingerprint: true
            archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            
            // Cleanup
            sh 'docker system prune -f 2>/dev/null || true'
        }
        
        success {
            echo "🎉🎉🎉 BUILD SUCCESSFUL! 🎉🎉🎉"
            
            script {
                // Get the minikube IP
                sh '''
                    MINIKUBE_IP=$(minikube ip)
                    SPRING_PORT=$(kubectl get svc spring-service -n ${K8S_NAMESPACE} -o jsonpath='{.spec.ports[0].nodePort}')
                    
                    echo "=== 🏆 DEPLOYMENT SUMMARY ==="
                    echo ""
                    echo "📦 Application Information:"
                    echo "   Name: Student Management System"
                    echo "   Docker Image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                    echo "   Build Number: #${BUILD_NUMBER}"
                    echo ""
                    echo "🌐 Access URLs:"
                    echo "   ✅ Spring Boot Application: http://${MINIKUBE_IP}:${SPRING_PORT}"
                    echo "   ✅ SonarQube Dashboard: http://${MINIKUBE_IP}:$(kubectl get svc sonarqube-service -n ${K8S_NAMESPACE} -o jsonpath='{.spec.ports[0].nodePort}')"
                    echo "   ✅ Prometheus: http://${MINIKUBE_IP}:30091"
                    echo "   ✅ Grafana: http://${MINIKUBE_IP}:30092 (admin/admin)"
                    echo ""
                    echo "🔧 Kubernetes Status:"
                    echo "   Namespace: ${K8S_NAMESPACE}"
                    echo "   Pods:"
                    kubectl get pods -n ${K8S_NAMESPACE}
                    echo ""
                    echo "📊 Docker Images:"
                    docker images | grep ${DOCKER_IMAGE}
                    echo ""
                    echo "🌟 All components deployed successfully!"
                '''
            }
        }
        
        failure {
            echo "❌❌❌ BUILD FAILED ❌❌❌"
            
            script {
                // Debug information
                sh '''
                    echo "=== Debug Information ==="
                    echo ""
                    echo "1. Workspace Contents:"
                    pwd
                    ls -la
                    echo ""
                    echo "2. Git Status:"
                    git status 2>/dev/null || echo "Not a git repo"
                    echo ""
                    echo "3. Maven Status:"
                    ls -la target/ 2>/dev/null || echo "No target directory"
                    echo ""
                    echo "4. Docker Status:"
                    docker images | grep ${DOCKER_IMAGE} 2>/dev/null || echo "No Docker images"
                    echo ""
                    echo "5. Kubernetes Status:"
                    kubectl get pods -n ${K8S_NAMESPACE} 2>/dev/null || echo "Cannot access K8S"
                '''
            }
        }
    }
}
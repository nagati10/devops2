pipeline {
    agent any

    environment {
        DOCKER_IMAGE = "najdnagati/student-management"
        DOCKER_TAG   = "${env.BUILD_NUMBER}"
        GIT_REPO     = "https://github.com/nagati10/devops2.git"
        GIT_BRANCH   = "main"
        SONAR_PROJECT_KEY = "student-management"
        SONAR_PROJECT_NAME = "Student Management System"
    }

    tools {
        maven 'M2_HOME'
        jdk   '$JAVA_HOME'
    }

    stages {
        stage('RÉCUPÉRATION CODE') {
            steps {
                git branch: "${GIT_BRANCH}", url: "${GIT_REPO}"
                
                sh '''
                    echo "✅ Code récupéré avec succès"
                    echo ""
                    echo "=== Contenu du répertoire ==="
                    pwd
                    ls -la
                '''
            }
        }

        stage('TESTS UNITAIRES & JaCoCo') {
            steps {
                sh "mvn clean test jacoco:report"
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }

        stage('VÉRIFICATION COUVERTURE') {
            steps {
                script {
                    sh '''
                        echo "🔍 Vérification de la couverture de code..."
                        
                        # Check JaCoCo report exists
                        if [ -f "target/site/jacoco/jacoco.xml" ]; then
                            echo "✅ Rapport JaCoCo généré avec succès"
                            
                            # Extract coverage percentage
                            COVERAGE=$(grep -o 'line-counter.*covered="[0-9]*"' target/site/jacoco/jacoco.xml | head -1 | grep -o '[0-9]*' | head -1)
                            if [ ! -z "$COVERAGE" ] && [ "$COVERAGE" -gt "0" ]; then
                                echo "✅ Couverture de code: $COVERAGE% (différente de 0)"
                            else
                                echo "⚠️  Couverture faible ou nulle"
                            fi
                        else
                            echo "❌ Échec: Rapport JaCoCo non généré"
                            exit 1
                        fi
                    '''
                }
            }
        }

        stage('ANALYSE SONARQUBE') {
            steps {
                script {
                    withSonarQubeEnv('SonarQube') {
                        sh """
                            echo "🔍 Lancement de l'analyse SonarQube..."
                            
                            mvn sonar:sonar \
                                -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                                -Dsonar.projectName="${SONAR_PROJECT_NAME}" \
                                -Dsonar.java.binaries=target/classes \
                                -Dsonar.junit.reportsPath=target/surefire-reports \
                                -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml
                            
                            echo "✅ Analyse SonarQube terminée"
                            echo "📊 Accédez au dashboard: http://localhost:9000/dashboard?id=${SONAR_PROJECT_KEY}"
                        """
                    }
                }
            }
        }

        stage('CONSTRUCTION LIVRABLE') {
            steps {
                sh "mvn package -DskipTests"
            }
        }

        stage('BUILD DOCKER IMAGE') {
            steps {
                script {
                    sh """
                        docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .
                        docker tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_IMAGE}:latest
                        echo "✅ Image Docker construite: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                    """
                }
            }
        }

        stage('PUSH DOCKERHUB') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'najdnagati',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh """
                        echo \$DOCKER_PASS | docker login -u \$DOCKER_USER --password-stdin
                        docker push ${DOCKER_IMAGE}:${DOCKER_TAG}
                        docker push ${DOCKER_IMAGE}:latest
                        docker logout || true
                        echo "✅ Images poussées sur DockerHub"
                    """
                }
            }
        }
        
        stage('DÉPLOIEMENT KUBERNETES') {
            steps {
                script {
                    sh '''
                        echo "=== Déploiement sur Kubernetes ==="
                        
                        # Set kubectl config
                        export KUBECONFIG=/var/lib/jenkins/.kube/config
                        
                        # Use full path to kubectl
                        KUBECTL_CMD="/usr/bin/kubectl"
                        
                        # Check if kubectl exists
                        if [ -f "$KUBECTL_CMD" ]; then
                            echo "✅ kubectl found at: $KUBECTL_CMD"
                            $KUBECTL_CMD version --client
                        else
                            echo "❌ kubectl not found at $KUBECTL_CMD"
                            echo "Trying /usr/local/bin/kubectl..."
                            KUBECTL_CMD="/usr/local/bin/kubectl"
                            if [ -f "$KUBECTL_CMD" ]; then
                                echo "✅ kubectl found at: $KUBECTL_CMD"
                                $KUBECTL_CMD version --client
                            else
                                echo "⚠️  kubectl not found. Creating symlink..."
                                # Try to create symlink
                                sudo ln -sf /usr/local/bin/kubectl /usr/bin/kubectl 2>/dev/null || true
                                KUBECTL_CMD="/usr/bin/kubectl"
                            fi
                        fi
                        
                        # Create namespace if not exists
                        echo "Creating/checking namespace..."
                        $KUBECTL_CMD create namespace devops --dry-run=client -o yaml | $KUBECTL_CMD apply -f -
                        
                        echo "✅ Namespace ready"
                    '''
                    
                    // Deploy MySQL
                    sh '''
                        echo "=== Déploiement MySQL ==="
                        
                        # Determine kubectl command
                        if [ -f "/usr/bin/kubectl" ]; then
                            KUBECTL_CMD="/usr/bin/kubectl"
                        else
                            KUBECTL_CMD="/usr/local/bin/kubectl"
                        fi
                        
                        # Check if MySQL is already deployed
                        if ! $KUBECTL_CMD get deployment mysql -n devops 2>/dev/null; then
                            echo "Deploying MySQL..."
                            $KUBECTL_CMD apply -f mysql-deployment.yaml -n devops
                            
                            # Wait for MySQL
                            echo "Waiting for MySQL to be ready..."
                            sleep 30
                            
                            # Check MySQL status
                            $KUBECTL_CMD get pods -n devops -l app=mysql
                            echo "✅ MySQL deployed"
                        else
                            echo "✅ MySQL already deployed"
                        fi
                    '''
                    
                    // Deploy Spring Boot
                    sh """
                        echo "=== Déploiement Spring Boot ==="
                        
                        # Determine kubectl command
                        if [ -f "/usr/bin/kubectl" ]; then
                            KUBECTL_CMD="/usr/bin/kubectl"
                        else
                            KUBECTL_CMD="/usr/local/bin/kubectl"
                        fi
                        
                        # Update the image in deployment file
                        sed -i "s|image:.*najdnagati/student-management.*|image: ${DOCKER_IMAGE}:${DOCKER_TAG}|g" spring-deployment.yaml
                        
                        # Apply deployment
                        \$KUBECTL_CMD apply -f spring-deployment.yaml -n devops
                        
                        # Wait for rollout
                        echo "Waiting for Spring Boot rollout..."
                        timeout 120 bash -c "while ! \$KUBECTL_CMD rollout status deployment/spring-app -n devops --timeout=1s 2>/dev/null; do sleep 5; echo 'Still deploying...'; done"
                        
                        echo "✅ Spring Boot deployed with image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                    """
                }
            }
        }
        
        stage('VÉRIFICATION DÉPLOIEMENT') {
            steps {
                sh '''
                    echo "=== Vérification du déploiement ==="
                    
                    # Determine kubectl command
                    if [ -f "/usr/bin/kubectl" ]; then
                        KUBECTL_CMD="/usr/bin/kubectl"
                    else
                        KUBECTL_CMD="/usr/local/bin/kubectl"
                    fi
                    
                    export KUBECONFIG=/var/lib/jenkins/.kube/config
                    
                    echo "1. État des pods:"
                    $KUBECTL_CMD get pods -n devops 2>/dev/null || echo "Cannot get pods"
                    
                    echo ""
                    echo "2. Services:"
                    $KUBECTL_CMD get svc -n devops 2>/dev/null || echo "Cannot get services"
                    
                    echo ""
                    echo "3. URL de l'application:"
                    if command -v minikube &> /dev/null; then
                        minikube service spring-service -n devops --url 2>/dev/null || echo "Getting service URL..."
                    else
                        echo "Minikube not available for URL generation"
                    fi
                    
                    echo "✅ Vérification terminée"
                '''
            }
        }
    }

    post {
        success {
            echo "🎉 PIPELINE TERMINÉ AVEC SUCCÈS !"
            echo "===================================="
            echo "📦 Image Docker: ${DOCKER_IMAGE}:${DOCKER_TAG}"
            echo "🐋 DockerHub: https://hub.docker.com/r/najdnagati/student-management"
            echo "📊 SonarQube: http://localhost:9000/dashboard?id=${SONAR_PROJECT_KEY}"
            echo "📈 Rapport JaCoCo: target/site/jacoco/index.html"
            echo "🔗 Code Source: ${GIT_REPO}"
            echo ""
            echo "🌐 Application déployée sur Kubernetes:"
            echo "   Namespace: devops"
            echo "   Service: spring-service"
            echo "   Port: 30080"
            echo "===================================="
            
            archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            sh "mvn clean || true"
        }
        failure {
            echo "❌ ÉCHEC DU PIPELINE"
            echo "Consultez les logs pour détails"
            sh "mvn clean || true"
        }
        always {
            echo "🧹 Nettoyage des ressources..."
            sh "docker system prune -f || true"
            
            // Archive important reports
            archiveArtifacts artifacts: 'target/surefire-reports/*.xml, target/site/jacoco/*', fingerprint: true
        }
    }
}
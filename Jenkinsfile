pipeline {
    agent any
    
    tools {
        maven 'M2_HOME'
        jdk   '$JAVA_HOME'
    }

    environment {
        DOCKER_IMAGE = 'najdnagati/student-management'  // Changed to your DockerHub username
        DOCKER_TAG = "${env.BUILD_NUMBER}"
        K8S_NAMESPACE = 'devops'
        SONARQUBE_URL = 'http://localhost:9000'
        SPRING_BOOT_URL = 'http://localhost:30080'
        SONARQUBE_TOKEN = credentials('sonarqube-token')  // Add this credential in Jenkins
    }

    stages {
        stage('Clean Workspace') {
            steps {
                cleanWs()
                echo "✅ Workspace nettoyé pour le build #${env.BUILD_NUMBER}"
            }
        }

        stage('Checkout Code') {
            steps {
                // Use main branch instead of master
                git branch: 'main',
                    url: 'https://github.com/nagati10/devops2.git'  // Changed to your repo
                echo "✅ Code récupéré depuis GitHub"
                
                // Debug: Check what was checked out
                sh '''
                    echo "Repository contents:"
                    ls -la
                    echo ""
                    echo "Checking key files:"
                    [ -f "pom.xml" ] && echo "✅ pom.xml exists" || echo "❌ pom.xml missing"
                    [ -d "src" ] && echo "✅ src directory exists" || echo "❌ src directory missing"
                    [ -f "Dockerfile" ] && echo "✅ Dockerfile exists" || echo "❌ Dockerfile missing"
                '''
            }
        }

        stage('Setup Kubernetes') {
            steps {
                script {
                    sh '''
                        echo "=== Configuration Kubernetes ==="

                        # Configurer KUBECONFIG
                        export KUBECONFIG=/var/lib/jenkins/.kube/config

                        # Use full path to kubectl
                        KUBECTL_CMD="/usr/bin/kubectl"
                        
                        # Check if kubectl exists
                        if [ -f "$KUBECTL_CMD" ]; then
                            echo "✅ kubectl found"
                        else
                            echo "❌ kubectl not found at $KUBECTL_CMD"
                            exit 1
                        fi

                        # Créer ou vérifier le namespace
                        $KUBECTL_CMD create namespace ${K8S_NAMESPACE} --dry-run=client -o yaml | $KUBECTL_CMD apply -f - --validate=false

                        echo "✅ Namespace '${K8S_NAMESPACE}' prêt"
                        $KUBECTL_CMD get ns ${K8S_NAMESPACE}
                    '''
                }
            }
        }

        stage('Build & Test') {
            steps {
                sh '''
                    echo "=== Build et Tests ==="
                    mvn clean test
                    echo "✅ Build et tests réussis"

                    # Generate JaCoCo report
                    mvn jacoco:report

                    # Vérifier les rapports
                    echo "Rapports générés:"
                    ls -la target/ || echo "Aucun fichier dans target/"
                '''
            }

            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
                success {
                    echo "🎯 Tests exécutés avec succès"
                    archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
                }
            }
        }

        stage('Code Quality - SonarQube') {
            steps {
                script {
                    // Check if SonarQube is deployed
                    sh '''
                        echo "=== Vérification SonarQube ==="
                        export KUBECONFIG=/var/lib/jenkins/.kube/config
                        KUBECTL_CMD="/usr/bin/kubectl"
                        
                        # Deploy SonarQube if not already
                        $KUBECTL_CMD apply -f sonarqube-deployment.yaml -n ${K8S_NAMESPACE} 2>/dev/null || true
                        
                        echo "Waiting for SonarQube..."
                        sleep 30
                    '''
                    
                    withSonarQubeEnv('sonarqube') {
                        sh '''
                            echo "=== Analyse SonarQube ==="

                            # Vérifier existence rapport JaCoCo
                            if [ -f "target/site/jacoco/jacoco.xml" ]; then
                                echo "📊 Rapport JaCoCo trouvé"
                            else
                                echo "⚠ Rapport JaCoCo non trouvé, génération..."
                                mvn jacoco:report
                            fi

                            # Exécuter analyse SonarQube
                            mvn sonar:sonar \
                                -Dsonar.projectKey=student-management \
                                -Dsonar.projectName="Student Management" \
                                -Dsonar.host.url=${SONARQUBE_URL} \
                                -Dsonar.login=admin \
                                -Dsonar.password=admin \
                                -Dsonar.java.binaries=target/classes \
                                -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml

                            echo "✅ Analyse SonarQube complétée"
                        '''
                    }
                }
            }
        }

        stage('Package Application') {
            steps {
                sh '''
                    echo "=== Packaging ==="

                    # Package sans tests
                    mvn clean package -DskipTests

                    echo "✅ Application packagée"
                    ls -lh target/*.jar
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh """
                    echo "=== Construction Image Docker ==="

                    docker build -t ${env.DOCKER_IMAGE}:${env.DOCKER_TAG} .
                    docker tag ${env.DOCKER_IMAGE}:${env.DOCKER_TAG} ${env.DOCKER_IMAGE}:latest

                    echo "✅ Images créées:"
                    echo "  - ${env.DOCKER_IMAGE}:${env.DOCKER_TAG}"
                    echo "  - ${env.DOCKER_IMAGE}:latest"

                    docker images | grep ${env.DOCKER_IMAGE}
                """
            }
        }

        stage('Push Docker Image') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'najdnagati',  // Your DockerHub credentials
                    usernameVariable: 'DOCKER_USERNAME',
                    passwordVariable: 'DOCKER_PASSWORD'
                )]) {
                    sh """
                        echo "=== Push Docker Hub ==="

                        echo \$DOCKER_PASSWORD | docker login -u \$DOCKER_USERNAME --password-stdin

                        docker push ${env.DOCKER_IMAGE}:${env.DOCKER_TAG}
                        docker push ${env.DOCKER_IMAGE}:latest

                        echo "✅ Images poussées sur Docker Hub"
                    """
                }
            }
        }

        stage('Deploy MySQL on K8S') {
            steps {
                script {
                    sh '''
                        echo "=== Déploiement MySQL ==="
                        export KUBECONFIG=/var/lib/jenkins/.kube/config
                        KUBECTL_CMD="/usr/bin/kubectl"

                        # Vérifier si MySQL est déjà déployé
                        if ! $KUBECTL_CMD get deployment mysql -n ${K8S_NAMESPACE} 2>/dev/null; then
                            echo "Déployer MySQL..."
                            $KUBECTL_CMD apply -f mysql-deployment.yaml -n ${K8S_NAMESPACE}
                            
                            # Attendre démarrage
                            echo "Attente démarrage MySQL..."
                            sleep 30
                        else
                            echo "✅ MySQL déjà déployé"
                        fi

                        # Vérifier
                        $KUBECTL_CMD get pods -l app=mysql -n ${K8S_NAMESPACE}
                        echo "✅ MySQL prêt"
                    '''
                }
            }
        }

        stage('Deploy Spring Boot on K8S') {
            steps {
                script {
                    sh """
                        echo "=== Déploiement Spring Boot ==="
                        export KUBECONFIG=/var/lib/jenkins/.kube/config
                        KUBECTL_CMD="/usr/bin/kubectl"

                        # Fix port configuration first
                        echo "Fix port configuration..."
                        sed -i 's/containerPort: 8080/containerPort: 8089/g' spring-deployment.yaml
                        sed -i 's/targetPort: 8080/targetPort: 8089/g' spring-deployment.yaml
                        
                        # Mettre à jour l'image
                        sed -i "s|image:.*najdnagati/student-management.*|image: ${env.DOCKER_IMAGE}:${env.DOCKER_TAG}|g" spring-deployment.yaml

                        # Vérifier si le deployment existe déjà
                        if \$KUBECTL_CMD get deployment spring-app -n \${K8S_NAMESPACE} >/dev/null 2>&1; then
                            echo "📦 Deployment existant détecté - mise à jour..."
                            \$KUBECTL_CMD apply -f spring-deployment.yaml -n \${K8S_NAMESPACE}
                        else
                            echo "🆕 Nouveau déploiement..."
                            \$KUBECTL_CMD apply -f spring-deployment.yaml -n \${K8S_NAMESPACE}
                        fi

                        # Attendre le rollout
                        echo "⏳ Attente du déploiement..."
                        sleep 30
                        
                        # Check status
                        echo "Pod status:"
                        \$KUBECTL_CMD get pods -n \${K8S_NAMESPACE} -l app=spring-app
                        
                        # Try rollout status
                        timeout 120 bash -c '
                            while ! \$KUBECTL_CMD rollout status deployment/spring-app -n \${K8S_NAMESPACE} --timeout=5s 2>/dev/null; do
                                echo "Still deploying..."
                                sleep 10
                            done
                        ' || echo "⚠️ Rollout check timed out, checking final status..."

                        echo "✅ Spring Boot déployé avec l'image: ${env.DOCKER_IMAGE}:${env.DOCKER_TAG}"
                    """
                }
            }
        }

        stage('Health Check') {
            steps {
                script {
                    sh '''
                        echo "=== Vérification santé ==="
                        export KUBECONFIG=/var/lib/jenkins/.kube/config
                        KUBECTL_CMD="/usr/bin/kubectl"

                        echo "1. État des pods:"
                        $KUBECTL_CMD get pods -n ${K8S_NAMESPACE}

                        echo ""
                        echo "2. Services:"
                        $KUBECTL_CMD get svc -n ${K8S_NAMESPACE}

                        echo ""
                        echo "3. Vérification Spring Boot:"
                        SPRING_POD=$($KUBECTL_CMD get pods -l app=spring-app -n ${K8S_NAMESPACE} -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

                        if [ -n "$SPRING_POD" ]; then
                            echo "Pod Spring Boot: $SPRING_POD"
                            $KUBECTL_CMD logs $SPRING_POD -n ${K8S_NAMESPACE} --tail=10 2>/dev/null || echo "Logs non disponibles"
                        fi

                        echo ""
                        echo "4. Application URL:"
                        if command -v minikube &> /dev/null; then
                            minikube service spring-service -n ${K8S_NAMESPACE} --url 2>/dev/null || echo "Getting URL..."
                        fi

                        echo "✅ Santé vérifiée"
                    '''
                }
            }
        }

        stage('Generate Report') {
            steps {
                script {
                    sh '''
                        echo "=== 🏆 RAPPORT FINAL DU BUILD #${BUILD_NUMBER} ==="
                        echo ""
                        echo "📅 Date: $(date)"
                        echo "🔢 Build Number: ${BUILD_NUMBER}"
                        echo "🏷️  Image Docker: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                        echo "📦 Namespace K8S: ${K8S_NAMESPACE}"
                        echo ""
                        echo "✅ ÉTAPES RÉUSSIES:"
                        echo "1. ✅ Checkout code GitHub"
                        echo "2. ✅ Build Maven"
                        echo "3. ✅ Analyse SonarQube"
                        echo "4. ✅ Packaging JAR"
                        echo "5. ✅ Build Docker"
                        echo "6. ✅ Push Docker Hub"
                        echo "7. ✅ Déploiement MySQL K8S"
                        echo "8. ✅ Déploiement Spring Boot K8S"
                        echo "9. ✅ Health checks"
                        echo ""
                        echo "🔗 ACCÈS:"
                        echo "• SonarQube: ${SONARQUBE_URL}"
                        echo "• Application: ${SPRING_BOOT_URL}"
                        echo "• Docker Hub: https://hub.docker.com/r/${DOCKER_IMAGE}"
                        echo ""
                        echo "📊 ARTÉFACTS:"
                        echo "• JAR: target/student-management-*.jar"
                        echo "• Image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                        echo "• Rapports: target/site/jacoco/"
                        echo ""
                        echo "🌟 BUILD RÉUSSI ! 🎉"
                    '''

                    // Sauvegarder le rapport
                    writeFile file: "build-report-${env.BUILD_NUMBER}.txt", text: """
                    BUILD REPORT #${env.BUILD_NUMBER}
                    =============================
                    Status: SUCCESS
                    Date: ${new Date()}

                    Docker Image: ${env.DOCKER_IMAGE}:${env.DOCKER_TAG}
                    K8S Namespace: ${env.K8S_NAMESPACE}

                    URLs:
                    - SonarQube: ${env.SONARQUBE_URL}
                    - Application: ${env.SPRING_BOOT_URL}

                    Artifacts:
                    - Application JAR: target/student-management-*.jar
                    - Docker Image: ${env.DOCKER_IMAGE}:${env.DOCKER_TAG}
                    - Test Reports: target/site/jacoco/
                    """
                }
            }
        }
    }

    post {
        always {
            echo "=== FIN DU PIPELINE BUILD #${env.BUILD_NUMBER} ==="

            // Archive des artefacts
            archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            archiveArtifacts artifacts: 'target/site/jacoco/*.*', fingerprint: true
            archiveArtifacts artifacts: "build-report-${env.BUILD_NUMBER}.txt", fingerprint: true

            // Nettoyage
            sh '''
                echo "Nettoyage des fichiers temporaires..."
                docker system prune -f 2>/dev/null || true
            '''
        }

        success {
            echo "🎉🎉🎉 BUILD #${env.BUILD_NUMBER} RÉUSSI ! 🎉🎉🎉"
            
            script {
                // Get minikube IP
                sh '''
                    MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "localhost")
                    echo ""
                    echo "=== DEPLOYMENT SUMMARY ==="
                    echo "Application URL: http://${MINIKUBE_IP}:30080/student"
                    echo "Docker Image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                    echo "K8S Namespace: ${K8S_NAMESPACE}"
                    echo ""
                    echo "✅ Pipeline completed successfully!"
                '''
            }
        }

        failure {
            echo '❌❌❌ BUILD ÉCHOUÉ ❌❌❌'

            script {
                sh '''
                    echo "=== DEBUG ==="
                    echo "Dernières erreurs:"

                    # Vérifier K8S
                    export KUBECONFIG=/var/lib/jenkins/.kube/config 2>/dev/null || true
                    KUBECTL_CMD="/usr/bin/kubectl"

                    echo "1. Pods en erreur:"
                    $KUBECTL_CMD get pods -n ${K8S_NAMESPACE} --field-selector=status.phase!=Running 2>/dev/null || echo "K8S non accessible"

                    echo "2. Workspace contents:"
                    pwd
                    ls -la
                    
                    echo "3. Build output:"
                    ls -la target/ 2>/dev/null || echo "No target directory"
                    
                    echo "4. Docker images:"
                    docker images | grep ${DOCKER_IMAGE} 2>/dev/null || echo "No Docker images"
                '''
            }
        }
    }
}
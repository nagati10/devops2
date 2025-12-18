pipeline {
    agent any

    environment {
        DOCKER_IMAGE = "najdnagati/student-management"
        DOCKER_TAG   = "1.0.0"
        GIT_REPO     = "https://github.com/nagati10/devops2.git"  // Changed to devops2
        GIT_BRANCH   = "main"
        SONAR_PROJECT_KEY = "student-management"
        SONAR_PROJECT_NAME = "Student Management System"
    }

    tools {
        maven 'M2_HOME'
        jdk   '$JAVA_HOME'  // This worked before
    }

    stages {
        stage('RÉCUPÉRATION CODE') {
            steps {
                // Remove credentials to test
                git branch: "${GIT_BRANCH}", url: "${GIT_REPO}"
                
                // Debug: Show what was checked out
                sh '''
                    echo "✅ Code récupéré avec succès"
                    echo ""
                    echo "=== Contenu du répertoire ==="
                    pwd
                    ls -la
                    echo ""
                    echo "=== Vérification des fichiers ==="
                    [ -f "pom.xml" ] && echo "✅ pom.xml trouvé" || echo "❌ pom.xml non trouvé"
                    [ -d "src" ] && echo "✅ src/ trouvé" || echo "❌ src/ non trouvé"
                    echo ""
                    echo "=== Information git ==="
                    git status
                    git branch -a
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
                        
                        # Configurer kubectl
                        export KUBECONFIG=/var/lib/jenkins/.kube/config
                        
                        # Créer namespace si nécessaire
                        kubectl create namespace devops --dry-run=client -o yaml | kubectl apply -f -
                        
                        echo "✅ Namespace prêt"
                    '''
                    
                    // Déployer MySQL
                    sh '''
                        echo "=== Déploiement MySQL ==="
                        
                        # Vérifier si MySQL est déjà déployé
                        if ! kubectl get deployment mysql -n devops 2>/dev/null; then
                            echo "Déploiement de MySQL..."
                            kubectl apply -f mysql-deployment.yaml -n devops
                            
                            # Attendre MySQL
                            echo "Attente du démarrage de MySQL..."
                            sleep 30
                            
                            # Vérifier MySQL
                            kubectl get pods -n devops -l app=mysql
                            echo "✅ MySQL déployé"
                        else
                            echo "✅ MySQL déjà déployé"
                        fi
                    '''
                    
                    // Déployer Spring Boot
                    sh """
                        echo "=== Déploiement Spring Boot ==="
                        
                        # Mettre à jour l'image dans le fichier de déploiement
                        sed -i "s|image:.*najdnagati/student-management.*|image: ${DOCKER_IMAGE}:${DOCKER_TAG}|g" spring-deployment.yaml
                        
                        # Appliquer le déploiement
                        kubectl apply -f spring-deployment.yaml -n devops
                        
                        # Attendre le déploiement
                        echo "Attente du déploiement Spring Boot..."
                        kubectl rollout status deployment/spring-app -n devops --timeout=300s
                        
                        echo "✅ Spring Boot déployé avec l'image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                    """
                }
            }
        }
        
        stage('VÉRIFICATION DÉPLOIEMENT') {
            steps {
                sh '''
                    echo "=== Vérification du déploiement ==="
                    
                    export KUBECONFIG=/var/lib/jenkins/.kube/config
                    
                    echo "1. État des pods:"
                    kubectl get pods -n devops
                    
                    echo ""
                    echo "2. Services:"
                    kubectl get svc -n devops
                    
                    echo ""
                    echo "3. URL de l'application:"
                    minikube service spring-service -n devops --url 2>/dev/null || echo "Récupération de l'URL..."
                    
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
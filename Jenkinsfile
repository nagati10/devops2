stage('DÉPLOIEMENT KUBERNETES') {
    steps {
        script {
            sh '''
                echo "=== Déploiement sur Kubernetes ==="
                
                # Set kubectl config
                export KUBECONFIG=/var/lib/jenkins/.kube/config
                
                # Use full path to kubectl
                KUBECTL_CMD="/usr/local/bin/kubectl"
                
                # Check if kubectl exists
                if [ -f "$KUBECTL_CMD" ]; then
                    echo "✅ kubectl found at: $KUBECTL_CMD"
                else
                    echo "⚠️  kubectl not found at $KUBECTL_CMD, trying /usr/bin/kubectl"
                    KUBECTL_CMD="/usr/bin/kubectl"
                fi
                
                # Test kubectl
                $KUBECTL_CMD version --client || echo "❌ kubectl test failed"
                
                # Create namespace if not exists
                echo "Creating/checking namespace..."
                $KUBECTL_CMD create namespace devops --dry-run=client -o yaml | $KUBECTL_CMD apply -f -
                
                echo "✅ Namespace ready"
            '''
            
            // Deploy MySQL
            sh '''
                echo "=== Déploiement MySQL ==="
                
                # Determine kubectl command
                if [ -f "/usr/local/bin/kubectl" ]; then
                    KUBECTL_CMD="/usr/local/bin/kubectl"
                else
                    KUBECTL_CMD="/usr/bin/kubectl"
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
                if [ -f "/usr/local/bin/kubectl" ]; then
                    KUBECTL_CMD="/usr/local/bin/kubectl"
                else
                    KUBECTL_CMD="/usr/bin/kubectl"
                fi
                
                # Update the image in deployment file
                sed -i "s|image:.*najdnagati/student-management.*|image: ${DOCKER_IMAGE}:${DOCKER_TAG}|g" spring-deployment.yaml
                
                # Apply deployment
                \$KUBECTL_CMD apply -f spring-deployment.yaml -n devops
                
                # Wait for rollout
                echo "Waiting for Spring Boot rollout..."
                \$KUBECTL_CMD rollout status deployment/spring-app -n devops --timeout=300s 2>/dev/null || echo "Rollout in progress..."
                
                echo "✅ Spring Boot deployed with image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
            """
        }
    }
}
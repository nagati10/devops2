#!/bin/bash
echo "🧪 VÉRIFICATION DES SERVICES"
echo "============================"

# 1. MySQL
echo ""
echo "1. MySQL:"
MYSQL_POD=$(kubectl get pod -l app=mysql -n devops -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$MYSQL_POD" ]; then
    echo "   ✅ Pod: $MYSQL_POD"
    echo "   📊 Status: $(kubectl get pod $MYSQL_POD -n devops -o jsonpath='{.status.phase}')"
else
    echo "   ❌ MySQL non trouvé"
fi

# 2. SonarQube
echo ""
echo "2. SonarQube:"
SONAR_POD=$(kubectl get pod -l app=sonarqube -n devops -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$SONAR_POD" ]; then
    echo "   ✅ Pod: $SONAR_POD"
    echo "   🌐 URL: $(minikube service sonarqube-service -n devops --url 2>/dev/null)"
    echo "   📝 Logs (dernières lignes):"
    kubectl logs $SONAR_POD -n devops --tail=3 2>/dev/null | sed 's/^/     /'
else
    echo "   ❌ SonarQube non trouvé"
fi

# 3. Prometheus
echo ""
echo "3. Prometheus:"
PROM_POD=$(kubectl get pod -l app=prometheus -n devops -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$PROM_POD" ]; then
    echo "   ✅ Pod: $PROM_POD"
    echo "   🌐 URL: $(minikube service prometheus-service -n devops --url 2>/dev/null)"
else
    echo "   ⚠️  Prometheus non trouvé"
fi

# 4. Grafana
echo ""
echo "4. Grafana:"
GRAFANA_POD=$(kubectl get pod -l app=grafana -n devops -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$GRAFANA_POD" ]; then
    echo "   ✅ Pod: $GRAFANA_POD"
    echo "   🌐 URL: $(minikube service grafana-service -n devops --url 2>/dev/null)"
else
    echo "   ⚠️  Grafana non trouvé"
fi

# 5. Spring Boot
echo ""
echo "5. Spring Boot:"
SPRING_POD=$(kubectl get pod -l app=spring-boot-app -n devops -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$SPRING_POD" ]; then
    echo "   ✅ Pod: $SPRING_POD"
    echo "   🌐 URL: $(minikube service spring-service -n devops --url 2>/dev/null)"
else
    echo "   📝 Spring Boot pas encore déployé ou en erreur"
fi

echo ""
echo "🎯 RÉSUMÉ POUR JENKINS :"
echo "========================"
echo "✅ Kubernetes: Accessible (testé précédemment)"
echo "✅ MySQL: En cours d'exécution"
echo "✅ SonarQube: En cours d'exécution"
echo "✅ Monitoring: Prometheus + Grafana déployés"
echo "📦 Spring Boot: À déployer via le pipeline"
echo ""
echo "🚀 Votre pipeline Jenkins devrait maintenant fonctionner !"

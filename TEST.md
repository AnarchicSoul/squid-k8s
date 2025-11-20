# Testing Squid Proxy on WSL with K3s

This guide provides step-by-step instructions to deploy and test the Squid proxy on your personal laptop using WSL and K3s.

## Prerequisites

### 1. Install K3s in WSL

If you don't have K3s installed yet:

```bash
# In WSL terminal
curl -sfL https://get.k3s.io | sh -

# Wait for K3s to be ready
sudo k3s kubectl get nodes

# Set up kubeconfig for kubectl
mkdir -p ~/.kube
sudo k3s kubectl config view --raw > ~/.kube/config
chmod 600 ~/.kube/config

# Verify kubectl works
kubectl get nodes
```

### 2. Install Helm in WSL

```bash
# In WSL terminal
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
helm version
```

## Deployment

### Option 1: Deploy from Local Helm Chart

If you have the repository cloned locally:

```bash
# Navigate to the repository
cd /path/to/squid-k8s

# Install the Helm chart
helm install squid-proxy ./helm-chart/squid-proxy \
  --namespace squid \
  --create-namespace

# Wait for deployment to be ready
kubectl wait --for=condition=available --timeout=120s \
  deployment/squid-proxy -n squid
```

### Option 2: Deploy from OCI Registry

Once the chart is published to Docker Hub:

```bash
# Install from OCI registry
helm install squid-proxy oci://registry-1.docker.io/johan91/squid-proxy \
  --namespace squid \
  --create-namespace
```

### Simple Custom Configuration

Create a file called `test-values.yaml`:

```yaml
# test-values.yaml - Simple configuration for testing
replicaCount: 1

# Use smaller resources for local testing
resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

# Disable persistence for quick testing
persistence:
  enabled: false

# Simple Squid configuration - allows all traffic
squidConfig: |
  # Simple test configuration
  http_port 3128

  # DNS servers
  dns_nameservers 8.8.8.8 8.8.4.4

  # Access control - PERMISSIVE for testing
  acl localnet src 0.0.0.0/0  # Allow from anywhere (TEST ONLY!)
  acl SSL_ports port 443
  acl Safe_ports port 80 443 21 70 210 1025-65535
  acl CONNECT method CONNECT

  # Deny unsafe ports
  http_access deny !Safe_ports
  http_access deny CONNECT !SSL_ports

  # Allow localhost
  http_access allow localhost manager
  http_access deny manager

  # Allow all for testing
  http_access allow localnet
  http_access allow localhost

  # Default deny
  http_access deny all

  # Minimal caching
  cache_dir ufs /var/spool/squid 100 16 256
  cache_mem 64 MB

  # Logging
  access_log /var/log/squid/access.log squid
  cache_log /var/log/squid/cache.log
```

Deploy with custom configuration:

```bash
# From repository directory
helm install squid-proxy ./helm-chart/squid-proxy \
  -f test-values.yaml \
  --namespace squid \
  --create-namespace
```

## Verify Deployment

```bash
# Check pod status
kubectl get pods -n squid

# Check service
kubectl get svc -n squid

# View logs
kubectl logs -f deployment/squid-proxy -n squid

# Get deployment details
kubectl describe deployment squid-proxy -n squid
```

## Testing the Proxy

### Method 1: Port Forward and Test from WSL

```bash
# Port forward the service to localhost
kubectl port-forward -n squid svc/squid-proxy 3128:3128
```

Keep this terminal running, and open a **new WSL terminal** to test:

```bash
# Test 1: Simple HTTP request through proxy
curl -x http://localhost:3128 http://example.com

# Test 2: Check headers
curl -x http://localhost:3128 -I http://example.com

# Test 3: Test HTTPS (if supported)
curl -x http://localhost:3128 https://example.com

# Test 4: Download a file
curl -x http://localhost:3128 http://ipinfo.io/json

# Test 5: Verbose output to see proxy interaction
curl -x http://localhost:3128 -v http://example.com
```

### Method 2: Test from Windows PowerShell

First, start port forwarding in WSL:

```bash
# In WSL
kubectl port-forward -n squid svc/squid-proxy 3128:3128
```

Then, open **PowerShell** on Windows:

```powershell
# Test 1: Using Invoke-WebRequest with proxy
Invoke-WebRequest -Uri "http://example.com" -Proxy "http://localhost:3128"

# Test 2: Get headers only
Invoke-WebRequest -Uri "http://example.com" -Proxy "http://localhost:3128" -Method Head

# Test 3: Test with curl (if installed via Windows)
curl.exe -x http://localhost:3128 http://example.com

# Test 4: Set proxy for entire PowerShell session
$env:HTTP_PROXY = "http://localhost:3128"
$env:HTTPS_PROXY = "http://localhost:3128"
Invoke-WebRequest -Uri "http://example.com"

# Test 5: Download JSON data
Invoke-WebRequest -Uri "http://ipinfo.io/json" -Proxy "http://localhost:3128" | Select-Object -ExpandProperty Content
```

### Method 3: Test from Inside the Cluster

```bash
# Create a test pod
kubectl run test-pod --image=curlimages/curl -n squid --rm -it --restart=Never -- sh

# Inside the pod, run:
curl -x http://squid-proxy:3128 http://example.com
curl -x http://squid-proxy:3128 http://ipinfo.io/json
exit
```

### Method 4: Configure Browser to Use Proxy

1. **Port forward** in WSL:
   ```bash
   kubectl port-forward -n squid svc/squid-proxy 3128:3128
   ```

2. **Configure your browser** (Chrome/Edge/Firefox):
   - Go to Settings → Network Settings → Manual Proxy Configuration
   - HTTP Proxy: `localhost`
   - Port: `3128`
   - Apply settings

3. **Visit websites** - traffic will go through the proxy

4. **Check proxy logs** to see requests:
   ```bash
   kubectl logs -f deployment/squid-proxy -n squid
   ```

## View Proxy Logs

```bash
# Follow logs in real-time
kubectl logs -f deployment/squid-proxy -n squid

# View last 100 lines
kubectl logs --tail=100 deployment/squid-proxy -n squid

# View access logs specifically (if you exec into pod)
kubectl exec -it deployment/squid-proxy -n squid -- tail -f /var/log/squid/access.log
```

## Testing Different Scenarios

### Test 1: Verify Caching

```bash
# First request (cache MISS)
time curl -x http://localhost:3128 http://example.com -o /dev/null -s

# Second request (should be faster - cache HIT)
time curl -x http://localhost:3128 http://example.com -o /dev/null -s

# Check cache log
kubectl exec -it deployment/squid-proxy -n squid -- grep TCP_HIT /var/log/squid/access.log
```

### Test 2: Test Access Control

Edit `test-values.yaml` to deny certain sites:

```yaml
squidConfig: |
  http_port 3128

  # Block specific domain
  acl blocked_sites dstdomain .facebook.com .twitter.com
  http_access deny blocked_sites

  acl localnet src 0.0.0.0/0
  http_access allow localnet
  http_access deny all
```

Update the deployment:

```bash
helm upgrade squid-proxy ./helm-chart/squid-proxy \
  -f test-values.yaml \
  --namespace squid
```

Test blocked site:

```bash
# Should be denied
curl -x http://localhost:3128 http://facebook.com
```

### Test 3: Performance Testing

```bash
# Install Apache Bench in WSL (if needed)
sudo apt-get update && sudo apt-get install -y apache2-utils

# Run performance test through proxy
ab -n 100 -c 10 -X localhost:3128 http://example.com/
```

## Cleanup

```bash
# Uninstall the Helm chart
helm uninstall squid-proxy -n squid

# Delete the namespace
kubectl delete namespace squid

# Verify cleanup
kubectl get all -n squid
```

## Troubleshooting

### Pod won't start

```bash
# Check pod events
kubectl describe pod -n squid -l app.kubernetes.io/name=squid-proxy

# Check pod logs
kubectl logs -n squid -l app.kubernetes.io/name=squid-proxy

# Check if image is pulled
kubectl get pods -n squid -o jsonpath='{.items[*].status.containerStatuses[*].image}'
```

### Connection refused

```bash
# Verify service endpoints
kubectl get endpoints -n squid

# Test from within cluster
kubectl run test --image=curlimages/curl -n squid --rm -it --restart=Never -- \
  curl -v http://squid-proxy:3128
```

### Configuration errors

```bash
# View current ConfigMap
kubectl get configmap -n squid squid-proxy -o yaml

# Test configuration syntax (exec into pod)
kubectl exec -it deployment/squid-proxy -n squid -- squid -k parse

# Restart deployment after config change
kubectl rollout restart deployment/squid-proxy -n squid
```

### Port forward not working from Windows

```bash
# Make sure WSL IP is accessible from Windows
# In WSL, find your IP:
ip addr show eth0 | grep inet

# In PowerShell, test connectivity:
Test-NetConnection -ComputerName <WSL-IP> -Port 3128

# Alternative: Use WSL2 localhost forwarding (usually automatic)
# Or bind to 0.0.0.0:
kubectl port-forward -n squid svc/squid-proxy 3128:3128 --address 0.0.0.0
```

## Advanced: Expose via NodePort (for easier Windows access)

Create `nodeport-values.yaml`:

```yaml
service:
  type: NodePort
  port: 3128
  nodePort: 30128  # Fixed port on node
```

Deploy:

```bash
helm upgrade --install squid-proxy ./helm-chart/squid-proxy \
  -f test-values.yaml \
  -f nodeport-values.yaml \
  --namespace squid \
  --create-namespace
```

Access from Windows PowerShell without port-forward:

```powershell
# Get WSL IP
wsl hostname -I

# Test (replace <WSL-IP> with actual IP)
curl.exe -x http://<WSL-IP>:30128 http://example.com
```

## Advanced: LoadBalancer with Static IP

**Note**: K3s includes a built-in ServiceLB controller that provides LoadBalancer implementation for on-premises clusters.

Create `loadbalancer-values.yaml`:

```yaml
service:
  type: LoadBalancer
  # For K3s, this will use the node's IP by default
  # You can specify a static IP from your network range
  loadBalancerIP: "192.168.1.100"
  # Restrict access to specific source IPs
  loadBalancerSourceRanges:
    - "192.168.0.0/16"
    - "10.0.0.0/8"
  # Use Local to preserve source IP
  externalTrafficPolicy: Local

# Squid configuration
squidConfig: |
  pid_filename /run/squid/squid.pid
  http_port 3128

  acl localnet src 0.0.0.0/0
  http_access allow localnet
  http_access deny all

  cache_dir ufs /var/spool/squid 100 16 256
  access_log /var/log/squid/access.log squid
```

Deploy:

```bash
helm upgrade --install squid-proxy ./helm-chart/squid-proxy \
  -f loadbalancer-values.yaml \
  --namespace squid \
  --create-namespace
```

Check the assigned external IP:

```bash
kubectl get svc squid-proxy -n squid
```

Test from WSL or Windows:

```bash
# Get the LoadBalancer IP
LB_IP=$(kubectl get svc squid-proxy -n squid -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test the proxy
curl -x http://$LB_IP:3128 http://example.com
```

From Windows PowerShell:

```powershell
# Get the LoadBalancer IP
$LB_IP = kubectl get svc squid-proxy -n squid -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Test the proxy
curl.exe -x http://${LB_IP}:3128 http://example.com
```

## Quick Reference

```bash
# Deploy
helm install squid-proxy ./helm-chart/squid-proxy -f test-values.yaml -n squid --create-namespace

# Port forward
kubectl port-forward -n squid svc/squid-proxy 3128:3128

# Test (in new terminal)
curl -x http://localhost:3128 http://example.com

# View logs
kubectl logs -f deployment/squid-proxy -n squid

# Update configuration
helm upgrade squid-proxy ./helm-chart/squid-proxy -f test-values.yaml -n squid

# Uninstall
helm uninstall squid-proxy -n squid
```

## Success Criteria

✅ Pod is running and healthy
✅ Service is accessible
✅ Can make HTTP requests through proxy
✅ Proxy logs show request activity
✅ Configuration changes are applied successfully

Happy testing! 🚀

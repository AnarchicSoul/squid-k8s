# Squid Proxy for Kubernetes

A production-ready Squid proxy server solution packaged as a Docker container and deployable to Kubernetes via Helm chart.

## Features

- 🐳 **Docker Container**: Pre-built Squid proxy container with security best practices
- ⎈ **Kubernetes Ready**: Helm chart for easy deployment to Kubernetes clusters
- 🔧 **Configurable**: Fully customizable Squid configuration via Helm values
- 📦 **OCI Registry**: Both Docker image and Helm chart available on Docker Hub
- 🔄 **CI/CD**: Automated builds and releases via GitHub Actions
- 📊 **Observability**: Health checks, logging, and metrics ready
- 💾 **Persistent Cache**: Optional persistent volume for caching

## Quick Start

### Docker

Run Squid proxy as a standalone Docker container:

```bash
docker run -d \
  --name squid-proxy \
  -p 3128:3128 \
  johan91/squid-proxy:latest
```

### Kubernetes (Helm)

Install Squid proxy to your Kubernetes cluster:

```bash
# Add the Helm chart from OCI registry
helm install squid-proxy oci://registry-1.docker.io/johan91/squid-proxy

# Or with custom values
helm install squid-proxy oci://registry-1.docker.io/johan91/squid-proxy \
  -f custom-values.yaml
```

## Configuration

### Customizing Squid Configuration

The Squid configuration can be fully customized via the Helm `values.yaml` file. Edit the `squidConfig` section:

```yaml
squidConfig: |
  # Your custom Squid configuration
  http_port 3128

  # Access control
  acl localnet src 10.0.0.0/8
  http_access allow localnet
  http_access deny all

  # Cache settings
  cache_dir ufs /var/spool/squid 100 16 256
  cache_mem 256 MB
```

### Example: Custom Values

Create a `custom-values.yaml` file:

```yaml
# Increase resources
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi

# Enable autoscaling
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

# Enable persistent cache
persistence:
  enabled: true
  size: 20Gi

# Custom Squid configuration
squidConfig: |
  http_port 3128

  # Your custom ACLs and rules
  acl internal_network src 192.168.0.0/16
  http_access allow internal_network
  http_access deny all

  # Enhanced caching
  cache_dir ufs /var/spool/squid 500 16 256
  cache_mem 512 MB
  maximum_object_size 10 MB
```

Deploy with custom values:

```bash
helm install squid-proxy oci://registry-1.docker.io/johan91/squid-proxy \
  -f custom-values.yaml
```

### Example: LoadBalancer with Static IP

Create a `loadbalancer-values.yaml` file:

```yaml
service:
  type: LoadBalancer
  # Specify a static IP (cloud provider dependent)
  loadBalancerIP: "192.168.1.100"
  # Optionally restrict access to specific source IPs
  loadBalancerSourceRanges:
    - "10.0.0.0/8"
    - "172.16.0.0/12"
  # Control traffic routing
  externalTrafficPolicy: Local

# Squid configuration with PID file fix
squidConfig: |
  pid_filename /run/squid/squid.pid
  http_port 3128

  # Allow from anywhere (adjust as needed)
  acl all src 0.0.0.0/0
  http_access allow all

  cache_dir ufs /var/spool/squid 100 16 256
  access_log /var/log/squid/access.log squid
```

Deploy with LoadBalancer:

```bash
helm install squid-proxy oci://registry-1.docker.io/johan91/squid-proxy \
  -f loadbalancer-values.yaml
```

Or use `--set` flags:

```bash
helm install squid-proxy oci://registry-1.docker.io/johan91/squid-proxy \
  --set service.type=LoadBalancer \
  --set service.loadBalancerIP="192.168.1.100" \
  --set service.externalTrafficPolicy=Local
```

## Architecture

### Components

1. **Docker Image** (`johan91/squid-proxy`)
   - Base: Ubuntu 22.04
   - Squid version: Latest stable from Ubuntu repositories
   - Security: Runs as non-root user (proxy:13)
   - Health checks included

2. **Helm Chart** (`oci://registry-1.docker.io/johan91/squid-proxy`)
   - Deployment with configurable replicas
   - Service (ClusterIP by default)
   - ConfigMap for Squid configuration
   - Optional PersistentVolumeClaim for cache
   - Optional HorizontalPodAutoscaler
   - ServiceAccount with minimal permissions

### File Structure

```
.
├── Dockerfile                          # Docker image definition
├── squid.conf                          # Default Squid configuration
├── .dockerignore                       # Docker build exclusions
├── helm-chart/
│   └── squid-proxy/
│       ├── Chart.yaml                  # Helm chart metadata
│       ├── values.yaml                 # Default values
│       ├── .helmignore                 # Helm package exclusions
│       └── templates/
│           ├── _helpers.tpl            # Template helpers
│           ├── configmap.yaml          # Squid config ConfigMap
│           ├── deployment.yaml         # Main deployment
│           ├── service.yaml            # Service definition
│           ├── serviceaccount.yaml     # ServiceAccount
│           ├── pvc.yaml                # Persistent volume claim
│           ├── hpa.yaml                # Autoscaler
│           └── NOTES.txt               # Post-install notes
└── .github/
    └── workflows/
        ├── docker-build-push.yaml      # Docker CI/CD
        └── helm-release.yaml           # Helm chart CI/CD
```

## GitHub Actions Workflows

### Docker Image Build and Push

Triggered on:
- Push to `main`/`master` branch
- Git tags (e.g., `v1.0.0`)
- Manual workflow dispatch

The workflow:
1. Builds multi-arch Docker images (amd64, arm64)
2. Tags with semantic versioning
3. Pushes to Docker Hub (`johan91/squid-proxy`)

### Helm Chart Release

Triggered on:
- Changes to `helm-chart/**` on `main`/`master`
- Release published
- Manual workflow dispatch

The workflow:
1. Packages the Helm chart
2. Pushes to Docker Hub OCI registry
3. Generates installation summary

## Prerequisites

### For GitHub Actions

Add the following secret to your GitHub repository:

- `DOCKER_HUB_TOKEN`: Docker Hub access token
  - Go to Docker Hub → Account Settings → Security → New Access Token
  - Add to GitHub: Settings → Secrets → Actions → New repository secret

## Local Development

### Building the Docker Image

```bash
docker build -t johan91/squid-proxy:dev .
```

### Testing the Docker Image

```bash
# Run the container
docker run -d --name squid-test -p 3128:3128 johan91/squid-proxy:dev

# Test the proxy
curl -x http://localhost:3128 http://example.com

# View logs
docker logs squid-test

# Clean up
docker stop squid-test
docker rm squid-test
```

### Testing the Helm Chart

```bash
# Lint the chart
helm lint helm-chart/squid-proxy

# Dry-run installation
helm install squid-proxy helm-chart/squid-proxy --dry-run --debug

# Install to local Kubernetes (minikube, kind, etc.)
helm install squid-proxy helm-chart/squid-proxy

# Test the deployment
kubectl get pods
kubectl logs -f deployment/squid-proxy

# Uninstall
helm uninstall squid-proxy
```

## Usage Examples

### Using the Proxy from Pods

Configure pods to use the proxy via environment variables:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: test
    image: curlimages/curl
    env:
    - name: HTTP_PROXY
      value: "http://squid-proxy:3128"
    - name: HTTPS_PROXY
      value: "http://squid-proxy:3128"
    - name: NO_PROXY
      value: "localhost,127.0.0.1,.svc,.cluster.local"
    command: ["sleep", "3600"]
```

### Port Forwarding for Local Testing

```bash
kubectl port-forward svc/squid-proxy 3128:3128

# In another terminal
curl -x http://localhost:3128 http://example.com
```

## Configuration Reference

### Helm Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `image.repository` | Docker image repository | `johan91/squid-proxy` |
| `image.tag` | Docker image tag | `latest` |
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.port` | Service port | `3128` |
| `service.loadBalancerIP` | Static IP for LoadBalancer | `""` |
| `service.loadBalancerSourceRanges` | Allowed source IP ranges | `[]` |
| `service.externalTrafficPolicy` | External traffic policy | `""` |
| `service.nodePort` | NodePort (if type is NodePort) | `""` |
| `resources.limits.cpu` | CPU limit | `500m` |
| `resources.limits.memory` | Memory limit | `512Mi` |
| `persistence.enabled` | Enable persistent cache | `true` |
| `persistence.size` | Cache volume size | `10Gi` |
| `autoscaling.enabled` | Enable HPA | `false` |
| `squidConfig` | Custom Squid configuration | See values.yaml |

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -l app.kubernetes.io/name=squid-proxy
kubectl describe pod <pod-name>
```

### View Logs

```bash
kubectl logs -f deployment/squid-proxy
```

### Test Connectivity

```bash
# From within the cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- sh
curl -x http://squid-proxy:3128 http://example.com
```

### Common Issues

1. **Pod not starting**: Check resource limits and node capacity
2. **Configuration errors**: Validate `squidConfig` syntax
3. **Connection refused**: Verify service and network policies
4. **Cache issues**: Check PVC status and storage class

## Security Considerations

- Runs as non-root user (UID 13)
- Read-only root filesystem for containers (where possible)
- Drops all capabilities
- Network policies can be applied for additional isolation
- Regular security updates via base image

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is open source and available under the MIT License.

## Support

For issues and questions:
- GitHub Issues: [https://github.com/johan91/squid-k8s/issues](https://github.com/johan91/squid-k8s/issues)
- Squid Documentation: [http://www.squid-cache.org/](http://www.squid-cache.org/)

## Acknowledgments

- Squid Cache project for the excellent proxy server
- Ubuntu for maintaining the official Squid packages
- Kubernetes and Helm communities

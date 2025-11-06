# CA3 AWS Deployment - Instance Sizing Analysis

## Resource Requirements Analysis

### Application Components Memory/CPU Needs:

**Data Services (Kafka, Zookeeper, MongoDB):**
- Kafka: 512Mi-1Gi RAM, 0.5-1 CPU (recommend 1Gi+ for production)
- Zookeeper: 256Mi RAM, 0.25 CPU
- MongoDB: 512Mi RAM, 0.5 CPU
- **Total: ~2Gi RAM, 1.75 CPU minimum**

**Application Services (Producer, Processor):**
- Producer: 128-256Mi RAM, 0.1-0.5 CPU
- Processor: 128-256Mi RAM, 0.1-0.5 CPU
- **Total: ~512Mi RAM, 0.5 CPU**

**Observability Stack:**
- Prometheus: 512Mi-1Gi RAM, 0.5 CPU
- Grafana: 256-512Mi RAM, 0.25 CPU
- Loki: 256-512Mi RAM, 0.25 CPU
- Promtail: 128Mi RAM, 0.1 CPU
- **Total: ~1.5Gi RAM, 1.1 CPU**

**System Overhead (K3s, OS, etc.):**
- K3s control plane: ~500Mi RAM, 0.5 CPU
- K3s agent: ~200Mi RAM, 0.2 CPU
- OS: ~300Mi RAM, 0.1 CPU
- **Total: ~1Gi RAM, 0.8 CPU per node**

---

## EC2 Instance Types Comparison

### t3.small (Current workers config)
- **vCPUs:** 2
- **RAM:** 2 GiB
- **Cost:** $0.0208/hr (~$15/month, ~$0.50/day)
- **Network:** Up to 5 Gigabit

### t3.medium (Recommended for Kafka)
- **vCPUs:** 2
- **RAM:** 4 GiB
- **Cost:** $0.0416/hr (~$30/month, ~$1/day)
- **Network:** Up to 5 Gigabit

### t3.large
- **vCPUs:** 2
- **RAM:** 8 GiB
- **Cost:** $0.0832/hr (~$60/month, ~$2/day)

---

## Recommended Configurations

### Option 1: Cost-Optimized (All t3.small) ⚠️ TIGHT
**Total Cost:** ~$1.50/day or ~$45/month

```
Master (t3.small):
  - Control plane + Observability
  - 2 vCPU, 2GB RAM
  - Components: K3s master, Prometheus, Grafana, Loki
  - Estimate: 1.5GB used (75% utilization)

Worker-1 (t3.small):  
  - Data Services
  - 2 vCPU, 2GB RAM
  - Components: Kafka, Zookeeper, MongoDB
  - Estimate: 1.8GB used (90% utilization) ⚠️ VERY TIGHT

Worker-2 (t3.small):
  - Application Services
  - 2 vCPU, 2GB RAM
  - Components: Producer, Processor, Promtail
  - Estimate: 1GB used (50% utilization)
```

**Analysis:**
- ✅ Cheapest option
- ⚠️ Worker-1 with Kafka will be very tight (may cause OOM)
- ⚠️ No room for HPA scaling
- ⚠️ May fail under load testing
- ⚠️ Kafka performance will be degraded

### Option 2: Balanced (t3.medium for data, t3.small for apps) ✅ RECOMMENDED
**Total Cost:** ~$2.42/day or ~$73/month

```
Master (t3.small):
  - Control plane + Observability
  - 2 vCPU, 2GB RAM
  - Components: K3s master, Prometheus, Grafana, Loki
  - Estimate: 1.5GB used (75% utilization)

Worker-1 (t3.medium):
  - Data Services
  - 2 vCPU, 4GB RAM
  - Components: Kafka, Zookeeper, MongoDB
  - Estimate: 2.5GB used (62% utilization) ✅ COMFORTABLE

Worker-2 (t3.small):
  - Application Services
  - 2 vCPU, 2GB RAM
  - Components: Producer, Processor, Promtail
  - Estimate: 1GB used (50% utilization)
```

**Analysis:**
- ✅ Kafka has breathing room
- ✅ Still allows HPA scaling for producer/processor
- ✅ Good balance of cost vs reliability
- ✅ Should handle load testing well
- 📊 Only $0.92/day more than all-small

### Option 3: Performance (t3.medium for all)
**Total Cost:** ~$3/day or ~$90/month

```
All nodes: t3.medium (2 vCPU, 4GB RAM)
```

**Analysis:**
- ✅ Maximum headroom for all components
- ✅ Best for HPA scaling
- ✅ Best for load testing
- ⚠️ Double the cost of Option 2
- ⚠️ Overkill for CA3 requirements

---

## Recommendation

**Go with Option 2 (Balanced):**
- Master: t3.small
- Worker-1 (data-services): t3.medium
- Worker-2 (application-services): t3.small

**Rationale:**
1. Kafka needs the extra RAM to avoid OOM under load
2. Producer/Processor are lightweight and can scale horizontally on t3.small
3. Observability stack (Prometheus/Grafana) can run on master with 2GB
4. Cost is only ~$2.42/day instead of $3/day (saves ~$17/month)
5. Meets CA3 requirements for resilience testing
6. Your assignment likely won't run more than a week = ~$17 total

**If budget is extremely tight:**
- Try Option 1 (all t3.small) but be prepared for Kafka issues
- Set memory limits aggressively on all pods
- Disable some observability components if needed
- May need to reduce Kafka retention or buffer settings

---

## Implementation

Update `terraform/main.tf` to support different instance types per node:
- Add `master_instance_type` variable
- Add `worker_1_instance_type` variable  
- Add `worker_2_instance_type` variable

This allows flexible sizing without changing the whole infrastructure.

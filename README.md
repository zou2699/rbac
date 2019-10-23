# rbac

https://blog.zouhl.com/post/%E5%9F%BA%E4%BA%8Erbac%E5%88%9B%E5%BB%BA%E5%8F%AA%E8%AF%BB%E7%94%A8%E6%88%B7/ 

## RBAC 基本概念

参见： 

- https://kubernetes.io/docs/reference/access-authn-authz/rbac/

- https://kubernetes.io/docs/reference/access-authn-authz/authentication/

  

### RBAC 用户角色相关

- 权限: 即对系统中指定资源的增删改查权限
- 角色: 将一定的权限组合在一起产生权限组，如管理员角色
- 用户: 具体的使用者，具有唯一身份标识(ID)，其后与角色绑定便拥有角色的对应权限

<!--more-->

权限和角色在kubernetes中都有记录，在rolebinding中都有体现，but 用户却不知道存放在哪里

`Normal users are assumed to be managed by an outside, independent service. An admin distributing private keys, a user store like Keystone or Google Accounts, even a file with a list of usernames and passwords.`

**也就是说，Kubernetes 是不负责维护存储用户数据的；对于 Kubernetes 来说，它识别或者说认识一个用户主要就几种方式**

- X509 Client Certs: 使用由 k8s 根 CA 签发的证书，提取 O 字段
- Static Token File: 预先在 API Server 放置 Token 文件(bootstrap 阶段使用过)
- Bootstrap Tokens: 一种在集群内创建的 Bootstrap 专用 Token(新的 Bootstarp 推荐)
- Static Password File: 跟静态 Token 类似
- Service Account Tokens: 使用 Service Account 的 Token

### RBAC 权限相关

RBAC 权限定义部分主要有三个层级

- apiGroups: 指定那个 API 组下的权限
- resources: 该组下具体资源，如 pod 等
- verbs: 指对该资源具体执行哪些动作

定义一组权限(角色)时要根据其所需的真正需求做最细粒度的划分

## 创建一个只读用户，并用于client-go

### 创建用户证书

首先根据上文可以得知，Kubernetes 不存储用户具体细节信息，也就是说只要通过它的那几种方式能进来的用户，Kubernetes 就认为它是合法的；那么为了让 kubectl 只读，所以我们需要先给它创建一个用来承载只读权限的用户；这里用户创建我们选择使用证书方式

cfssl https://github.com/cloudflare/cfssl/wiki/Creating-a-new-CSR

cfssl下载链接 https://pkg.cfssl.org/

```json
# 创建一个用于签发的json，使用cfssl
{
  "CN": "client-readonly",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "SiChuan",
      "L": "ChengDu",
      "O": "devops",
      "OU": "Operations"
    }
  ]
}
```

然后基于以 Kubernetes CA 证书创建只读用户的证书

```shell
./cfssl gencert --ca /etc/kubernetes/pki/ca.crt \
                --ca-key /etc/kubernetes/pki/ca.key \
                --config ca-config.json \
                --profile  kubernetes readonly.json | \
                ./cfssljson --bare readonly
```

### 创建kubeconfig

```bash
#!/bin/bash

KUBE_API_SERVER="https://10.6.64.131:6443"
CERT_DIR=${2:-"/etc/kubernetes/pki"}

kubectl config set-cluster default-cluster --server=${KUBE_API_SERVER} \
    --certificate-authority=${CERT_DIR}/ca.crt \
    --embed-certs=true \
    --kubeconfig=readonly.kubeconfig

kubectl config set-credentials devops \
    --certificate-authority=${CERT_DIR}/ca.crt \
    --embed-certs=true \
    --client-key=readonly-key.pem \
    --client-certificate=readonly.pem \
    --kubeconfig=readonly.kubeconfig

kubectl config set-context default-system --cluster=default-cluster \
    --user=devops \
    --kubeconfig=readonly.kubeconfig

kubectl config use-context default-system --kubeconfig=readonly.kubeconfig
```

这条命令会将证书也写入到 readonly.kubeconfig 配置文件中，将该文件放在 `~/.kube/config` 位置，kubectl 会自动读取



### 创建ClusterRole 和 ClusterRoleBinding

```yaml
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: cluster-readonly
rules:
- apiGroups:
  - ""
  resources:
  - pods
  - pods/attach
  - pods/exec
  - pods/portforward
  - pods/proxy
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - configmaps
  - endpoints
  - persistentvolumeclaims
  - replicationcontrollers
  - replicationcontrollers/scale
  - secrets
  - serviceaccounts
  - services
  - services/proxy
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - bindings
  - events
  - limitranges
  - namespaces/status
  - pods/log
  - pods/status
  - replicationcontrollers/status
  - resourcequotas
  - resourcequotas/status
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - namespaces
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - apps
  resources:
  - deployments
  - deployments/rollback
  - deployments/scale
  - statefulsets
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - autoscaling
  resources:
  - horizontalpodautoscalers
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - batch
  resources:
  - cronjobs
  - jobs
  - scheduledjobs
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - extensions
  resources:
  - daemonsets
  - deployments
  - ingresses
  - replicasets
  verbs:
  - get
  - list
  - watch

---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: cluster-readonly
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-readonly
subjects:
  - kind: Group  # 基于组  name和 readonly.json 中组织的名字一样devops
    name: devops
    apiGroup: rbac.authorization.k8s.io
```

绑定到User上

```yaml
subjects:
  - kind: User
    name: client-readonly  # 基于用户 name 和 readonly.json 中CN的名字一样 client-readonly
    apiGroup: rbac.authorization.k8s.io
```



### 测试权限

```shell
kubectl --kubeconfig readonly.kubeconfig get pod
```

在client-go中测试

```bash
$ go run main.go           
NAME            Replicas        AvailableReplicas
demoapp         2               2               
demoapp2        2               2               
watching...
2019/10/23 15:54:23 deployment demoapp2 added
2019/10/23 15:54:23 deployment demoapp added

```



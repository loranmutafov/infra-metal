apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: /etc/kubernetes/pki/ca.crt
    server: https://vmi389591.contaboserver.net:6443
  name: cluster
contexts:
- context:
    cluster: cluster
    user: kubelet-bootstrap
  name: kubelet-bootstrap
current-context: kubelet-bootstrap
users:
- name: kubelet-bootstrap
  user:
    token: {{ pass://Rea Cluster/Kubelet Bootstrap Token/Password }}

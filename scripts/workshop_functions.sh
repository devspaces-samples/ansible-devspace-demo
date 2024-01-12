#!/bin/bash

W_USER=${W_USER:-user}
W_PASS=${W_PASS:-openshift}
GROUP_ADMINS=workshop-admins
# GROUP_USERS=workshop-users
TMP_DIR=scratch
# HTPASSWD=htpasswd-workshop-secret
# WORKSHOP_USERS=25

usage(){
  echo "Workshop: Functions Loaded"
  echo ""
  echo "usage: workshop_[setup,reset,clean]"
}

doing_it_wrong(){
  echo "usage: source scripts/workshop-functions.sh"
}

is_sourced() {
  if [ -n "$ZSH_VERSION" ]; then
      case $ZSH_EVAL_CONTEXT in *:file:*) return 0;; esac
  else  # Add additional POSIX-compatible shell names here, if needed.
      case ${0##*/} in dash|-dash|bash|-bash|ksh|-ksh|sh|-sh) return 0;; esac
  fi
  return 1  # NOT sourced.
}

check_init(){
  # do you have oc
  which oc > /dev/null || exit 1

  # create generated folder
  [ ! -d ${TMP_DIR} ] && mkdir -p ${TMP_DIR}
}

workshop_create_user_htpasswd(){
  FILE=${TMP_DIR}/htpasswd
  touch ${FILE}

  which htpasswd || return

  for i in {1..50}
  do
    htpasswd -bB ${FILE} "${W_USER}${i}" "${W_PASS}${i}"
  done

  echo "created: ${FILE}" 
  # oc -n openshift-config create secret generic ${HTPASSWD} --from-file=${FILE}
  # oc -n openshift-config set data secret/${HTPASSWD} --from-file=${FILE}

}

workshop_create_user_ns(){
  OBJ_DIR=${TMP_DIR}/users
  [ -e ${OBJ_DIR} ] && rm -rf ${OBJ_DIR}
  [ ! -d ${OBJ_DIR} ] && mkdir -p ${OBJ_DIR}

  for i in {1..50}
  do

# create ns
cat << YAML >> "${OBJ_DIR}/namespace.yaml"
---
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    openshift.io/display-name: Start Here - ${W_USER}${i}
  name: ${W_USER}${i}
YAML

# create rolebinding
cat << YAML >> "${OBJ_DIR}/admin-rolebinding.yaml"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${W_USER}${i}-admin
  namespace: ${W_USER}${i}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: ${W_USER}${i}
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: ${GROUP_ADMINS}
YAML
  done

  # apply objects created in scratch dir
    oc apply -f ${OBJ_DIR}

}

cluster_autoscale_test(){
  APPS_INGRESS=apps.cluster-cfzzs.sandbox1911.opentlc.com
  NOTEBOOK_IMAGE_NAME=s2i-minimal-notebook:1.2
  NOTEBOOK_SIZE="Demo / Workshop"

  for i in {1..50}
  do

echo "---
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: test
  name: test
  namespace: ${W_USER}${i}
spec:
  containers:
  - name: test
    image: quay.io/devfile/universal-developer-image:ubi8-latest
    command:
      - sleep
      - infinity
    resources:
      requests:
        cpu: 500m
        memory: 8Gi
  restartPolicy: Always
" | oc apply -f -
  done
}

workshop_load_test(){
  APPS_INGRESS=apps.cluster-cfzzs.sandbox1911.opentlc.com
  NOTEBOOK_IMAGE_NAME=s2i-minimal-notebook:1.2
  NOTEBOOK_SIZE="Demo / Workshop"

  for i in {1..50}
  do

      NB_USER="user${i}"

echo "---
apiVersion: workspace.devfile.io/v1alpha2
kind: DevWorkspace
metadata:
  name: python-hello-world
  namespace: ${W_USER}${i}
  labels:
    controller.devfile.io/creator: ''
spec:
  contributions:
    - kubernetes:
        name: che-code-python-hello-world
      name: editor
  routingClass: che
  started: true
  template:
    attributes:
      controller.devfile.io/devworkspace-config:
        name: devworkspace-config
        namespace: devspaces
      controller.devfile.io/storage-type: per-user
    commands:
      - exec:
          commandLine: python3 hello-world.py
          component: tools
          group:
            kind: run
          label: Run application
          workingDir: '${PROJECT_SOURCE}'
        id: run-application
    components:
      - container:
          image: 'quay.io/devfile/universal-developer-image:ubi8-latest'
          memoryLimit: 512Mi
          mountSources: true
          sourceMapping: /projects
          volumeMounts:
            - name: venv
              path: /home/user/.venv
        name: tools
      - name: venv
        volume:
          size: 1G
    projects:
      - name: python-hello-world
        zip:
          location: >-
            https://eclipse-che.github.io/che-devfile-registry/main/resources/v2/python-hello-world.zip
" | oc apply -f -
  done
}

workshop_load_test_clean(){
  oc -n rhods-notebooks delete notebooks.kubeflow.org --all
  oc -n rhods-notebooks delete pvc --all
}

workshop_clean_user_ns(){
  for i in {1..50}
  do
    oc delete project "${W_USER}${i}"
  done
}

workshop_clean_user_notebooks(){
  oc -n rhods-notebooks \
    delete po -l app=jupyterhub
}

workshop_setup(){
  check_init
  workshop_create_user_htpasswd
  workshop_create_user_ns
}

workshop_clean(){
  echo "Workshop: Clean User Namespaces"
  check_init
  workshop_clean_user_ns
  workshop_clean_user_notebooks
}

workshop_reset(){
  echo "Workshop: Reset"
  check_init
  workshop_clean
  sleep 8
  workshop_setup
}

is_sourced && usage
is_sourced || doing_it_wrong

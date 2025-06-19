pipeline {
    agent {
        docker {
            image 'ghcr.io/cloudogu/helm:3'
            args '--entrypoint=""'
        }
    }

    environment {
        HELM_REPO_URL = 'ghcr.io/cloudogu'
        CHART_VERSION = sh(script: "grep '^version:' Chart.yaml | awk '{print \$2}'", returnStdout: true).trim()
        CHART_NAME = sh(script: "grep '^name:' Chart.yaml | awk '{print \$2}'", returnStdout: true).trim()

    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    // Jenkins seems to do a sparse checkout only, but we want to check tags as well
                    sh "git fetch --tags --force"
                }
            }
        }

        stage('Validate Chart') {
            steps {
                sh '''
                    helm version
                    helm lint .
                '''
            }
        }

        stage('Run Unit Tests') {
            steps {
                sh '''
                    helm plugin install https://github.com/helm-unittest/helm-unittest > /dev/null
                    helm unittest .
                '''
            }
        }

        stage('Package Chart') {
            steps {
                sh '''
                    helm package .
                '''
                archiveArtifacts artifacts: "*.tgz", fingerprint: true
            }
        }

        stage('Push to Helm Repository') {
            when {
                branch 'main'
            }
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'cesmarvin-ghcr', usernameVariable: 'USER', passwordVariable: 'PASSWORD')]) {
                        sh '''
                            helm registry login ${HELM_REPO_URL} -u $USER -p $PASSWORD

                            if helm pull oci://${HELM_REPO_URL}/${CHART_NAME}  --version $CHART_VERSION; then
                                echo "Error: Chart version already exists in repository"
                                exit 1
                            fi

                            # Seems difficult with jenkins
                            # git tag $CHART_VERSION
                            # git push --tags

                            CURRENT_TAG=$(git tag --points-at HEAD)
                            
                            # Check if both conditions are true
                            if [[ -n "$CURRENT_TAG" ]] && [[ "$CURRENT_TAG" == "$CHART_VERSION" ]]; then
                                helm push $(ls *.tgz) oci://${HELM_REPO_URL}
                                echo "$CHART_VERSION" > pushedVersion.txt
                            else
                                echo "Not pushing :"
                                if [[ -z "$CURRENT_TAG" ]]; then
                                    echo "- Current HEAD has no tag"
                                else
                                    echo "- Current HEAD tag: $CURRENT_TAG"
                                    echo "- Chart version: $CHART_VERSION"
                                    echo "Tag and chart version missmatch!"
                                    exit 1
                                fi
                            fi
                        '''

                        if (fileExists('pushedVersion.txt')) {
                            currentBuild.description = "$HELM_REPO_URL/$CHART_NAME:${readFile 'pushedVersion.txt'}"
                            sh 'rm pushedVersion.txt'
                        }
                    }
                }
            }
        }
    }
}
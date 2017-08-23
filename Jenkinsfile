node('scc-jenkins-node-chucker') {
    stage('checkout') {
        git url: 'https://github.com/suse/rmt.git', branch: 'docker-pipeline-with-reference-host'
    }

    stage('build and push the image') {
        sh 'docker build -t registry.scc.suse.de/rmt:latest .'
        sh 'docker push registry.scc.suse.de/rmt:latest'
    }

    stage('staging deploy') {
        sh 'ssh root@rmt.scc.suse.de -t "docker pull registry.scc.suse.de/rmt:latest"'
        try {
            sh 'ssh root@rmt.scc.suse.de -t "docker stop rmt_production && docker rm rmt_production || true"'
        }
        finally {
            sh 'ssh root@rmt.scc.suse.de -t "docker run -d --name rmt_production --network=rmt_network -e POSTGRES_HOST=postgres -e SECRET_KEY_BASE=\\$SECRET_KEY_BASE -e RMT_ORGANIZATION_USERNAME=\\$RMT_ORGANIZATION_USERNAME -e RMT_ORGANIZATION_PASSWORD=\\$RMT_ORGANIZATION_PASSWORD -v rmt_public_volume:/srv/www/rmt/public/ registry.scc.suse.de/rmt"'
            sh 'ssh root@rmt.scc.suse.de -t "docker exec -e POSTGRES_HOST=postgres rmt_production bundle exec rails db:migrate"'
        }
    }
}

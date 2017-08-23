def ssh = 'ssh root@rmt.scc.suse.de -t'

node('scc-jenkins-node-chucker') {
    stage('checkout') {
        git url: 'https://github.com/suse/rmt.git', branch: 'docker-pipeline-with-reference-host'
    }

    stage('build and push the image') {
        sh 'docker build -t registry.scc.suse.de/rmt:latest .'
        sh 'docker push registry.scc.suse.de/rmt:latest'
    }

    stage('staging deploy') {
        sh '${ssh} "docker pull registry.scc.suse.de/rmt:latest"'
        try {
            sh 'ssh root@rmt.scc.suse.de -t "docker stop rmt_production"'
            sh 'ssh root@rmt.scc.suse.de -t "docker rm rmt_production"'
        }
        finally {
            sh '${ssh} "docker run -d --name rmt_production --network=rmt_network -e POSTGRES_HOST=postgres -e SECRET_KEY_BASE=$SECRET_KEY_BASE -v rmt_public_volume:/srv/www/rmt/public/ registry.scc.suse.de/rmt"'
            sh '${ssh} "docker exec -e POSTGRES_HOST=postgres rmt_production bundle exec rails db:migrate"'
        }
    }
}

node('scc-jenkins-node-chucker') {
    stage('checkout') {
        git url: 'https://github.com/suse/rmt.git', branch: 'master'
    }

    stage('build and push the image') {
        sh 'docker build -t registry.scc.suse.de/rmt:latest .'
        sh 'docker push registry.scc.suse.de/rmt:latest'
    }

    stage('staging deploy') {
        sh 'ssh root@rmt.scc.suse.de -t "docker pull registry.scc.suse.de/rmt:latest"'
        try {
            sh 'ssh root@rmt.scc.suse.de -t "docker stop rmt_production && docker rm rmt_production || true"'
            sh 'ssh root@rmt.scc.suse.de -t "docker stop rmt_cron && docker rm rmt_cron || true"'
        }
        finally {
            sh 'ssh root@rmt.scc.suse.de -t "docker run --restart=always -d --name rmt_production --network=rmt_network -e SECRET_KEY_BASE=\\$SECRET_KEY_BASE -e RMT_ORGANIZATION_USERNAME=\\$RMT_ORGANIZATION_USERNAME -e RMT_ORGANIZATION_PASSWORD=\\$RMT_ORGANIZATION_PASSWORD -v /media/rmt-data/:/srv/www/rmt/public/ -v /var/run/mysql/mysql.sock:/var/run/mysql/mysql.sock registry.scc.suse.de/rmt"'
            sh 'ssh root@rmt.scc.suse.de -t "docker exec rmt_production bundle exec rails db:migrate"'
            sh 'ssh root@rmt.scc.suse.de -t "docker run --restart=always -d --name rmt_cron --network=rmt_network -e SECRET_KEY_BASE=\\$SECRET_KEY_BASE -e RMT_ORGANIZATION_USERNAME=\\$RMT_ORGANIZATION_USERNAME -e RMT_ORGANIZATION_PASSWORD=\\$RMT_ORGANIZATION_PASSWORD -v /media/rmt-data/:/srv/www/rmt/public/ -v /var/www/rmt/shared/config/crontab:/etc/config/crontab -v /var/run/mysql/mysql.sock:/var/run/mysql/mysql.sock registry.scc.suse.de/rmt cron -n /etc/config/crontab"'
        }
    }
}

node('scc-jenkins-node-chucker') {
    stage('checkout') {
        git url: 'https://github.com/suse/rmt.git', branch: 'master'
    }

    dir('rmt') {
        stage('build and push the image') {
            sh 'docker build -t registry.scc.suse.de/rmt:latest .'
            sh 'docker push registry.scc.suse.de/rmt:latest'
          }
        }

        stage('staging deploy') {
            sh 'ssh root@10.162.213.12 -t "docker pull registry.scc.suse.de/rmt:latest && docker stop rmt && docker rm rmt && docker run -d --name rmt -e RAILS_ENV=production -p 3000:3000 registry.scc.suse.de/rmt"'
        }
    }
}

node('scc-jenkins-node-chucker') {
    stage('checkout') {
        git url: 'https://github.com/suse/rmt.git', branch: 'master'
    }

    stage('docker-compose build') {
        dir('rmt') {
            sh 'docker-compose build'
        }
    }

    stage('run tests') {
        dir('rmt') {
            sh 'docker-compose run rmt bash -c "bundler.ruby2.4 && rails db:migrate && rspec"'
        }
    }
}

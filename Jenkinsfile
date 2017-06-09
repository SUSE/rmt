node('scc-jenkins-node-chucker-v2') {
    stage('checkout') {
        git url: 'https://gitlab.suse.de/scc/smt-ng.git', branch: 'master'
    }

    stage('docker-compose build') {
        dir('smt-ng') {
            sh 'docker-compose build'
        }
    }

    stage('run tests') {
        dir('smt-ng') {
            sh 'docker-compose run smt_ng rspec'
        }
    }
}

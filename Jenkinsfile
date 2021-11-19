pipeline {
    agent { label 'marvin-clone' }
    stages {
        stage('test-github-slurm') {
            steps {
                sshagent(['jenkins']) {
                    sh """ 
                           #source /etc/bashrc
                           virtualenv venv -p python3.8 
                           source venv/bin/activate
                           pip install -r requirements.txt
                           cp .tests/integration2/config.yaml config.yaml
                           module load singularity
                           module load slurm-drmaa
                           snakemake -s workflow/Snakefile --use-singularity --profile .tests/integration2/profiles/slurm
                       """
                }
            }
        }
    }
}

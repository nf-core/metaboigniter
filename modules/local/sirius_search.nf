
process SIRIUS_SEARCH{
    tag "$meta.id"
    label 'process_high_long'
    conda "bioconda::sirius-csifingerid=5.8.6"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/sirius-csifingerid:5.8.6--h3bb291f_0' :
        'biocontainers/sirius-csifingerid:5.8.6--h3bb291f_0' }"

    input:
    tuple val(meta), path(input_target)


    output:
    tuple val(meta),path("sirius_*.tsv"), emit: sirius_tsv,optional: true
    tuple val(meta),path("fingerid_*.tsv"), emit: fingerid_tsv,optional: true
    path  "versions.yml"                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
        """
    if [ "$workflow.containerEngine" = "singularity" ] || [ "$workflow.containerEngine" = "apptainer" ]; then
        export CONDA_PREFIX="/usr/local"
    fi
    mkdir sirius_wd
    mkdir siris_project

    siriussearch.sh --input $input_target --output sirius_${input_target.baseName}.tsv --outputfid fingerid_${input_target.baseName}.tsv --prfolder siris_project --project_processors $task.cpus $args --workspace \$PWD/sirius_wd

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sirius: \$(sirius --workspace \$PWD/sirius_wd  --version | grep -Eo "SIRIUS [0-9]+\\.[0-9]+\\.[0-9]+" | awk '{print \$2}' 2>/dev/null)
    END_VERSIONS
        """
}


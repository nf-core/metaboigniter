process MS2QUERY_SEARCH {
    tag "$meta.id"
    label 'process_long'

    conda "bioconda::ms2query=1.2.3"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ms2query:1.2.3--pyhdfd78af_0' :
        'biocontainers/ms2query:1.2.3--pyhdfd78af_0' }"



    input:
    tuple val(meta), path(msms)
    tuple path(modelfiles,stageAs: "model/*")
    output:
    tuple val(meta), path("output/*.csv"), emit: csv
    path  "versions.yml"               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''


        """

        mkdir output
        ms2query --spectra $msms --library model/ $args --results output/



    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ms2query: \$(python -c "import ms2query; print(ms2query.__version__)" 2>/dev/null)
    END_VERSIONS
        """
}

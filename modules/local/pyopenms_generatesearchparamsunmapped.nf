process PYOPENMS_GENERATESEARCHPARAMSUNMAPPED {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::pyopenms=2.9.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pyopenms:2.9.1--py311h9b8898c_3' :
        'biocontainers/pyopenms:2.9.1--py311h9b8898c_3' }"

    input:
    tuple val(meta),path(input_spectra),path(input_csv)

    output:
    tuple val(meta), path({  meta.id+'.ms' }), emit: ms, optional: true
    tuple val(meta), path({  meta.id+'.mgf' }), emit: mgf,optional: true
    path  "versions.yml"                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

        """
        mkdir output
        sirius_params_single.py --mzml_file_path $input_spectra --input_csv $input_csv --ms_output ${prefix}.ms --mgf_output ${prefix}.mgf $args


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyopenms: \$(python -c "import pyopenms; print(pyopenms.__version__)" 2>&1 | grep -v "Warning:")
    END_VERSIONS
        """
}

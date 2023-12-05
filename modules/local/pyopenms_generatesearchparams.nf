process PYOPENMS_GENERATESEARCHPARAMS{
    tag "$meta.id"
    label 'process_high'

    conda "bioconda::pyopenms=2.9.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pyopenms:2.9.1--py311h9b8898c_3' :
        'quay.io/biocontainers/pyopenms:2.9.1--py311h9b8898c_3' }"

    input:
    tuple val(meta), path(input_target)
    tuple val(meta_spec),path(input_spectra)

    output:
    tuple val(meta), path({  meta.id+'.ms' }), emit: ms, optional: true
    tuple val(meta_spec), path("output/*.csv"), emit: csv, optional: true
    tuple val(meta), path({  meta.id+'.mgf' }), emit: mgf,optional: true
    path  "versions.yml"                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def map_index = meta.part ? "_part${meta.part}":''
    def mzml_input        = input_spectra.collect { it }.join(' ')
    def csv_output        = input_spectra.collect { "output/${it.baseName}${map_index}.csv" }.join(' ')


        """
    mkdir output



            generate_ms_params.py --consensus_file_path $input_target --mzml_file_paths $mzml_input --csv_output $csv_output --ms_output ${prefix}.ms --mgf_output ${prefix}.mgf $args


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pyopenms: \$(python -c "import pyopenms; print(pyopenms.__version__)" 2>/dev/null)
    END_VERSIONS
        """
}

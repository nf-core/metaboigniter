#!/bin/bash

# Function to convert argument names
convert_arg_name() {
    echo "$1" | sed 's/_/-/g'
}

# Default values
workspace_sirius_default="./workspace"
output_default="sirius.tsv"
outputfid_default="fingerid.tsv"
prfolder_default="./output"
project_maxmz_default=-1
project_processors_default=1
project_loglevel_default="WARNING"
project_ignore_formula_default=false
sirius_ppm_max_default=10.0
sirius_ppm_max_ms2_default=10.0
sirius_tree_timeout_default=100
sirius_compound_timeout_default=100
sirius_no_recalibration_default=false
sirius_no_isotope_score_default=false
sirius_no_isotope_filter_default=false
sirius_profile_default="default"
sirius_formulas_default=""
sirius_ions_enforced_default=""
sirius_candidates_default=10
sirius_candidates_per_ion_default=1
sirius_elements_considered_default="SBrClBSe"
sirius_elements_enforced_default="CHNOP"
sirius_ions_considered_default="[M+H]+,[M+K]+,[M+Na]+,[M+H-H2O]+,[M+H-H4O2]+,[M+NH4]+,[M-H]-,[M+Cl]-,[M-H2O-H]-,[M+Br]-"
sirius_db_default=""
runfid_default=false
runpassatutto_default=false
fingerid_db_default=""
sirius_solver_default="CLP"
email_default=""
password_default=""
executable_default="sirius"

# Initialize variables to defaults
workspace_sirius=$workspace_sirius_default
output=$output_default
outputfid=$outputfid_default
prfolder=$prfolder_default
project_maxmz=$project_maxmz_default
project_processors=$project_processors_default
project_loglevel=$project_loglevel_default
project_ignore_formula=$project_ignore_formula_default
sirius_ppm_max=$sirius_ppm_max_default
sirius_ppm_max_ms2=$sirius_ppm_max_ms2_default
sirius_tree_timeout=$sirius_tree_timeout_default
sirius_compound_timeout=$sirius_compound_timeout_default
sirius_no_recalibration=$sirius_no_recalibration_default
sirius_no_isotope_score=$sirius_no_isotope_score_default
sirius_no_isotope_filter=$sirius_no_isotope_filter_default
sirius_profile=$sirius_profile_default
sirius_formulas=$sirius_formulas_default
sirius_ions_enforced=$sirius_ions_enforced_default
sirius_candidates=$sirius_candidates_default
sirius_candidates_per_ion=$sirius_candidates_per_ion_default
sirius_elements_considered=$sirius_elements_considered_default
sirius_elements_enforced=$sirius_elements_enforced_default
sirius_ions_considered=$sirius_ions_considered_default
sirius_db=$sirius_db_default
runfid=$runfid_default
runpassatutto=$runpassatutto_default
fingerid_db=$fingerid_db_default
sirius_solver=$sirius_solver_default
email=$email_default
password=$password_default
executable=$executable_default

# Parse command line arguments
while [ "$#" -gt 0 ]; do
    case "$1" in
        --input) input="$2"; shift ;;
        --output) output="$2"; shift ;;
        --outputfid) outputfid="$2"; shift ;;
        --prfolder) prfolder="$2"; shift ;;
        --project_maxmz) project_maxmz="$2"; shift ;;
        --project_processors) project_processors="$2"; shift ;;
        --project_loglevel) project_loglevel="$2"; shift ;;
        --project_ignore-formula) project_ignore_formula=true ;;
        --sirius_ppm-max) sirius_ppm_max="$2"; shift ;;
        --sirius_ppm-max-ms2) sirius_ppm_max_ms2="$2"; shift ;;
        --sirius_tree-timeout) sirius_tree_timeout="$2"; shift ;;
        --sirius_compound-timeout) sirius_compound_timeout="$2"; shift ;;
        --sirius_no-recalibration) sirius_no_recalibration=true ;;
        --sirius_no-isotope-score) sirius_no_isotope_score=true ;;
        --sirius_no-isotope-filter) sirius_no_isotope_filter=true ;;
        --sirius_profile) sirius_profile="$2"; shift ;;
        --sirius_formulas) sirius_formulas="$2"; shift ;;
        --sirius_ions-enforced) sirius_ions_enforced="$2"; shift ;;
        --sirius_candidates) sirius_candidates="$2"; shift ;;
        --sirius_candidates-per-ion) sirius_candidates_per_ion="$2"; shift ;;
        --sirius_elements-considered) sirius_elements_considered="$2"; shift ;;
        --sirius_elements-enforced) sirius_elements_enforced="$2"; shift ;;
        --sirius_ions-considered) sirius_ions_considered="$2"; shift ;;
        --sirius_db) sirius_db="$2"; shift ;;
        --runfid) runfid=true ;;
        --runpassatutto) runpassatutto=true ;;
        --fingerid_db) fingerid_db="$2"; shift ;;
        --sirius_solver) sirius_solver="$2"; shift ;;
        --email) email="$2"; shift ;;
        --password) password="$2"; shift ;;
        --executable) executable="$2"; shift ;;
	--workspace) workspace_sirius="$2"; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# Login if email and password are provided
if [ -n "$email" ] && [ -n "$password" ]; then
$executable  --noCite --workspace "$workspace_sirius"  login --email="$email" --password="$password"
fi

# Construct command line
command_line="$executable --noCite --workspace $workspace_sirius "

# Add project-related options if not default
for key in maxmz processors loglevel ignore_formula; do
    varname="project_$key"
    default_varname="project_${key}_default"
    eval "value=\$$varname"
    eval "default_value=\$$default_varname"
    if [ "$value" != "$default_value" ]; then
        arg_name=$(convert_arg_name "$key")
        if [ "$value" = true ]; then
            command_line+=" --$arg_name"
        else
            command_line+=" --$arg_name $value"
        fi
    fi
done

# Add input and project folder if not default
if [ "$input" != "" ]; then
    command_line+=" --input $input"
fi
if [ "$prfolder" != "$prfolder_default" ]; then
    command_line+=" --project $prfolder"
fi
command_line+=" --no-compression sirius"

# Add sirius-related options if not default
for key in ppm_max ppm_max_ms2 tree_timeout compound_timeout no_recalibration no_isotope_score no_isotope_filter profile formulas ions_enforced candidates candidates_per_ion elements_considered elements_enforced ions_considered db solver; do
    varname="sirius_$key"
    default_varname="sirius_${key}_default"
    eval "value=\$$varname"
    eval "default_value=\$$default_varname"
    if [ "$value" != "$default_value" ]; then
        arg_name=$(convert_arg_name "$key")
        if [ "$value" = true ]; then
            command_line+=" --$arg_name"
        else
            command_line+=" --$arg_name $value"
        fi
    fi
done

# Add boolean flags if not default

if [ "$runpassatutto" != "$runpassatutto_default" ]; then
    command_line+=" passatutto"
fi

if [ "$runfid" != "$runfid_default" ]; then
    command_line+=" fingerprint structure"
fi


# Add fingerid-related options if not default
if [ "$fingerid_db" != "$fingerid_db_default" ]; then
    command_line+=" --db $fingerid_db"
fi

command_line+=" write-summaries"

# Execute command
#echo $command_line
eval $command_line

# Define the function to list directories
list_directories() {
    for i in "$1"/*; do
        if [ -d "$i" ]; then
            echo "${i##*/}"  # Extracts only the directory name
        fi
    done
}

# Extracts Spectrum MS Information
extractSpectrumMSInfo() {
    local sirius_spectrum_ms="$1/spectrum.ms"
    local ext_mz ext_rt ext_n_id

    if [ -f "$sirius_spectrum_ms" ]; then
        while IFS= read -r line; do
            case "$line" in
                ">parentmass"*) ext_mz=$(echo "$line" | sed 's/>parentmass//g' | xargs) ;;
                ">rt"*) ext_rt=$(echo "$line" | sed 's/>rt//g' | sed 's/s//g' | xargs) ;;
                "##best_feature_id"*) ext_n_id+=$(echo "$line" | sed 's/##best_feature_id//g' | xargs) ;;
            esac
        done < "$sirius_spectrum_ms"
    else
        echo "File not found: $sirius_spectrum_ms"
        exit 1
    fi

    echo "$ext_mz $ext_rt $ext_n_id"
}

# Main processing logic
process_files() {
    local output_file="$1"
    local type="$2"
    local all_lines=()
    local header_set=false
tab=$(printf '\t')
    for target in $(list_directories "$prfolder"); do
        IFS='-' read -ra parts <<< "${target##*_}"
        local feature_id=${parts[0]}
        local scan_index=${parts[1]}
        local scan_id=${parts[3]}
        local full_path="$prfolder/$target/${type}_candidates.tsv"
        local folder_path="$prfolder/$target"
        local spc_info=$(extractSpectrumMSInfo "$folder_path")
        local ext_mz=$(echo $spc_info | cut -d ' ' -f 1)
        local ext_rt=$(echo $spc_info | cut -d ' ' -f 2)
        local ext_n_id=$(echo $spc_info | cut -d ' ' -f 3)

        if [ -f "$full_path" ]; then
            while IFS= read -r line || [ -n "$line" ]; do
                if [ "$header_set" = false ]; then
                    header="Feature_ID${tab}Scan_Index${tab}Scan_ID${tab}Spectra_RT${tab}Spectra_mz${tab}Best_Feature_ID${tab}$line"
                    all_lines+=("$header")
                    header_set=true
                else
                    new_line="$feature_id${tab}$scan_index${tab}$scan_id${tab}$ext_rt${tab}$ext_mz${tab}$ext_n_id${tab}$line"
                    all_lines+=("$new_line")
                fi
            done < "$full_path"
        fi
    done

    # Write to output file if there are lines to write
    if [ ${#all_lines[@]} -gt 0 ]; then
        printf "%s\n" "${all_lines[@]}" > "$output_file"
    else
        echo "No metabolites were detected"
    fi
}

# Run for sirius.tsv
process_files "$output" "formula"

# Run for fingerid.tsv if $runfid is true
if [ "$runfid" = true ]; then
    process_files "$outputfid" "structure"
fi

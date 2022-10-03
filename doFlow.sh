hosp_cred_file=.creds_hosp.json
cleaner_cred_file=.creds_clean.json
admin_cred_file=.creds_admin.json

admin_key="$(cat ${admin_cred_file} | jq -r '.key')"

hospital_name="$(cat ${hosp_cred_file} | jq -r '.name')"
hospital_username="$(cat ${hosp_cred_file} | jq -r '.username')"
hospital_email="$(cat ${hosp_cred_file} | jq -r '.email')"
hospital_lat="$(cat ${hosp_cred_file} | jq -r '.lat')"
hospital_long="$(cat ${hosp_cred_file} | jq -r '.long')"
hospital_addr="$(cat ${hosp_cred_file} | jq -r '.addr')"
hospital_note="$(cat ${hosp_cred_file} | jq -r '.note')"
hospital_hmac="$(cat ${hosp_cred_file} | jq -r '."seedServerSideShard.HMAC"')"
hospital_id="$(cat ${hosp_cred_file} | jq -r '.id')"

cleaner_name="$(cat ${cleaner_cred_file} | jq -r '.name')"
cleaner_username="$(cat ${cleaner_cred_file} | jq -r '.username')"
cleaner_email="$(cat ${cleaner_cred_file} | jq -r '.email')"
cleaner_lat="$(cat ${cleaner_cred_file} | jq -r '.lat')"
cleaner_long="$(cat ${cleaner_cred_file} | jq -r '.long')"
cleaner_addr="$(cat ${cleaner_cred_file} | jq -r '.addr')"
cleaner_note="$(cat ${cleaner_cred_file} | jq -r '.note')"
cleaner_hmac="$(cat ${cleaner_cred_file} | jq -r '."seedServerSideShard.HMAC"')"
cleaner_id="$(cat ${cleaner_cred_file} | jq -r '.id')"

if [ "${hospital_email} " == " " ] || [ "${cleaner_email} " == " " ]
then
    echo "credentials not set"
    echo "==${hospital_email}==${cleaner_email}=="
    exit -1
fi

# read the endpoint
case "${1}" in
        "testing")
            my_endpoint='http://65.109.11.42:9000/api'
        ;;
        *)
            echo "Please specify a valid back-end"
            exit -1
        ;;
esac

# perform init or read units from disk
if [ "${2} " = "Y " ]
then
    do_init="true"
fi

if [ "${3} " = "Y " ]
then
    do_debug="true"
fi

my_nodered='localhost:1880/interfacer'

machine=$(echo "${my_endpoint}" | sed 's/http[s]*:\/\/\(.*\)[:0-9]*\/api/\1/g')
init_file="init_${machine}.json"



body=""
exctcont_filename='extract_contracts'

function update_field {
    orig_file=${1}
    prefixed_field=${2}
    new_value=${3}

    update_tmpfile=$(mktemp)
    cp ${orig_file} "${update_tmpfile}" &&
    # jq --arg field "$prefixed_field" --arg prefix "$prefix" --arg newvalue "$new_value" '.[$prefix].[$field] |= $newvalue'  ${update_tmpfile} > ${orig_file} &&
    jq --argjson prefixed_field "$prefixed_field" --arg newvalue "${new_value}" 'setpath( $prefixed_field; $newvalue)' ${update_tmpfile} > ${orig_file} &&
    rm -f -- "${update_tmpfile}"
}

function signRequest {
    variables=${1}
    query=${2}
    zenKeysFile=${3}

    sign_tmpfile=$(mktemp)
    # echo ${sign_tmpfile}
    echo "{\"a\":\"b\"}" > ${sign_tmpfile}
    update_field "${sign_tmpfile}" "[\"variables\"]" "${variables}" &&
    update_field "${sign_tmpfile}" "[\"query\"]" "${query}" &&
    encoded=$(cat "${sign_tmpfile}" | jq tostring | base64) &&
    update_field "${sign_tmpfile}" "[\"gql\"]" "${encoded}" &&
    cp "${sign_tmpfile}" ss.json &&
    json_result=$(~/bin/zenroom-osx.command -a "${sign_tmpfile}" -k ${zenKeysFile} -z sign.zen) &&
    rm -f -- "${sign_tmpfile}" &&
    echo ${json_result}
}

function getHMAC {
    body="{\"email\" : \"${1}\", \"endpoint\" : \"${my_endpoint}\" }"
    result=$(curl -X POST -H "Content-Type: application/json" -d "${body}" ${my_nodered}/getHMAC 2>/dev/null)
    json_result="{\"result\": $result, \"body\": $body}"
    echo ${json_result}
}

function createPerson {
    body="{\"name\" : \"${1}\", \"username\" : \"${2}\", \"email\" : \"${3}\", \"eddsaPublicKey\" : \"${4}\", \"key\" : \"${admin_key}\", \"endpoint\" : \"${my_endpoint}\" }"
    result=$(curl -X POST -H "Content-Type: application/json" -d "${body}" ${my_nodered}/createPerson 2>/dev/null)
    json_result="{\"result\": $result, \"body\": $body}"
    echo ${json_result}
}

function createLocation {
    body="{\"eddsa\" : \"${1}\", \"username\" : \"${2}\", \"name\" : \"${3}\", \"lat\" : ${4}, \"long\" : ${5}, \"addr\" : \"${6}\", \"note\" : \"${7}\", \"endpoint\" : \"${my_endpoint}\" }"
    result=$(curl -X POST -H "Content-Type: application/json" -d "${body}" ${my_nodered}/createLocation 2>/dev/null)
    json_result="{\"result\": $result, \"body\": $body}"
    echo ${json_result}
}

function createUnit {
    body="{\"eddsa\" : \"${1}\", \"label\" : \"${2}\", \"symbol\" : \"${3}\", \"endpoint\" : \"${my_endpoint}\" }"
    result=$(curl -X POST -H "Content-Type: application/json" -d "${body}" ${my_nodered}/unit 2>/dev/null)
    json_result="{\"result\": $result, \"body\": $body}"
    echo ${json_result}
}

function createProcess {
    body="{\"eddsa\" : \"${1}\", \"process_name\" : \"${2}\", \"process_note\" : \"${3}\", \"endpoint\" : \"${my_endpoint}\" }"
    result=$(curl -X POST -H "Content-Type: application/json" -d "${body}" ${my_nodered}/process 2>/dev/null)
    json_result="{\"result\": $result, \"body\": $body}"
    echo ${json_result}
}

function transferCustody {

    body="{\"eddsa\" : \"${1}\", \"provider_id\" : \"${2}\", \"receiver_id\" : \"${3}\", \"resource_id\" : \"${4}\", \"unit_id\" : \"${5}\", \"amount\" : ${6}, \"location_id\" : \"${7}\", \"note\": \"${8}\", \"endpoint\" : \"${my_endpoint}\" }"
    result=$(curl -X POST -H "Content-Type: application/json" -d "${body}" ${my_nodered}/transfer 2>/dev/null)
    json_result="{\"result\": $result, \"body\": $body}"
    echo ${json_result}
}

function createResourceSpec {

    body="{\"eddsa\" : \"${1}\", \"unit_id\" : \"${2}\", \"name\" : \"${3}\", \"note\" : \"${4}\", \"classification\" : \"${5}\", \"endpoint\" : \"${my_endpoint}\" }"
    result=$(curl -X POST -H "Content-Type: application/json" -d "${body}" ${my_nodered}/resourcespec 2>/dev/null)
    json_result="{\"result\": $result, \"body\": $body}"
    echo ${json_result}
}

function createResource {
    body="{\"eddsa\" : \"${1}\", \"agent_id\" : \"${2}\", \"resource_name\" : \"${3}\", \"resource_id\" : \"${4}\", \"unit_id\" : \"${5}\", \"amount\" : ${6}, \"classification\": \"${7}\", \"endpoint\" : \"${my_endpoint}\" }"
    result=$(curl -X POST -H "Content-Type: application/json" -d "${body}" ${my_nodered}/resource 2>/dev/null)
    json_result="{\"result\": $result, \"body\": $body}"
    echo ${json_result}
}

function createEvent {
    
    action=${1}
    common_body="\"action\" : \"${action}\", \"eddsa\" : \"${2}\",  \"note\": \"${3}\", \"provider_id\" : \"${4}\", \"receiver_id\" : \"${5}\", \"unit_id\" : \"${6}\", \"amount\" : ${7}, \"endpoint\" : \"${my_endpoint}\""

    case "${action}" in
        "work")
            body="{ ${common_body}, \"processIn_id\" : \"${8}\", \"classification\": \"${9}\"}"
        ;;
        "accept")
            body="{ ${common_body}, \"processIn_id\" : \"${8}\", \"resource_id\" : \"${9}\"}"
        ;;
        "modify")
            body="{ ${common_body}, \"processOut_id\" : \"${8}\", \"resource_id\" : \"${9}\"}"
        ;;
        "consume")
            body="{ ${common_body}, \"processIn_id\" : \"${8}\", \"resource_id\" : \"${9}\"}"
        ;;
        "produce")
            body="{ ${common_body}, \"processOut_id\" : \"${8}\", \"resourcetrack_id\" : \"${9}\", \"resource_name\" : \"${10}\", \"classification\": \"${11}\"}"
        ;;
        *)
            echo "Please specify a valid action"
        ;;
	esac

    result=$(curl -X POST -H "Content-Type: application/json" -d "${body}" ${my_nodered}/event 2>/dev/null)
    json_result="{\"result\": $result, \"body\": $body}"
    echo ${json_result}
}

function traceTrack {

    body="{\"resource_id\" : \"${1}\", \"recursion\" : ${2}, \"endpoint\" : \"${my_endpoint}\" }"
    result=$(curl -X POST -H "Content-Type: application/json" -d "${body}" ${my_nodered}/tracetrack 2>/dev/null)
    json_result="{\"result\": $result, \"body\": $body}"
    echo ${json_result}
}

################################################################################
##### Get credentials for the 2 users
################################################################################
################################################
##### Get the contract from the checked-out repo
################################################
tsc ./${exctcont_filename}.ts
node ./${exctcont_filename}.js

if [ "${hospital_id} " == "null " ]
then
    ################################################
    ##### Get the HMAC for the hospital
    ################################################
    result=$(getHMAC ${hospital_email})
    hospital_seed=$(echo ${result} | jq -r '.result.seed')
    if [ "${do_debug} " == "true " ]
    then
        echo "DEBUG: $(date) -  result is: ${result}"
        echo "DEBUG: $(date) -  hospital_seed is ${hospital_seed}" 
    fi

    if [ "${hospital_seed} " == " " ]
    then
        echo "Getting seed failed for ${hospital_username}"
        exit -1
    fi
    echo "$(date) - Got seed for user hospital, seed: ${hospital_seed}"
    # jq --arg newhmac "$hospital_seed" '."seedServerSideShard.HMAC" |= $newhmac'  > ${hosp_cred_file}
    update_field ${hosp_cred_file} "[\"seedServerSideShard.HMAC\"]" $hospital_seed

    ################################################
    ##### Generate keys
    ################################################
    result=$(~/bin/zenroom-osx.command -a ${hosp_cred_file} -z keypairoomClient.zen)

    if [ "${do_debug} " == "true " ]
        then
            echo "DEBUG: $(date) -  result is: $(echo ${result} | jq '.')"
            # echo "$(date) - lochospital_id is ${lochospital_id}" 
        fi

    seed=$(echo ${result} | jq -r '.seed')
    eddsa_public_key=$(echo ${result} | jq -r '.eddsa_public_key')
    eddsa_private_key=$(echo ${result} | jq -r '.keyring.eddsa')
    update_field ${hosp_cred_file} "[\"seed\"]" "$seed"
    update_field ${hosp_cred_file} "[\"eddsa_public_key\"]" "$eddsa_public_key"
    update_field ${hosp_cred_file} "[\"keyring\",\"eddsa\"]" "$eddsa_private_key"

    ################################################
    ##### Create the person
    ################################################
    result=$(createPerson "${hospital_name}" ${hospital_username} ${hospital_email} ${eddsa_public_key})
    if [ "${do_debug} " == "true " ]
        then
            echo "DEBUG: $(date) -  result is: $(echo ${result} | jq '.')"
            # echo "$(date) - lochospital_id is ${lochospital_id}" 
        fi

    hospital_id=$(echo ${result} | jq -r '.result.id')
    update_field ${hosp_cred_file} "[\"id\"]" "$hospital_id"
else
    echo "Data for hospital seems to be already available"
fi

if [ "${cleaner_id} " == "null " ]
then
    ################################################
    ##### Get the HMAC for the cleaner
    ################################################
    result=$(getHMAC ${cleaner_email})
    cleaner_seed=$(echo ${result} | jq -r '.result.seed')
    if [ "${do_debug} " == "true " ]
    then
        echo "DEBUG: $(date) -  result is: ${result}"
        echo "DEBUG: $(date) -  cleaner_seed is ${cleaner_seed}" 
    fi
    if [ "${cleaner_seed} " == " " ]
    then
        echo "Getting seed failed for ${cleaner_username}"
        exit -1
    fi
    echo "$(date) - Got seed for user cleaner, seed: ${cleaner_seed}"
    update_field ${cleaner_cred_file} "[\"seedServerSideShard.HMAC\"]" $cleaner_seed

    ################################################
    ##### Generate keys
    ################################################
    result=$(~/bin/zenroom-osx.command -a ${cleaner_cred_file} -z keypairoomClient.zen)

    if [ "${do_debug} " == "true " ]
    then
        echo "DEBUG: $(date) -  result is: $(echo ${result} | jq '.')"
        # echo "$(date) - lochospital_id is ${lochospital_id}" 
    fi

    seed=$(echo ${result} | jq -r '.seed')
    eddsa_public_key=$(echo ${result} | jq -r '.eddsa_public_key')
    eddsa_private_key=$(echo ${result} | jq -r '.keyring.eddsa')
    update_field ${cleaner_cred_file} "[\"seed\"]" "$seed"
    update_field ${cleaner_cred_file} "[\"eddsa_public_key\"]" "$eddsa_public_key"
    update_field ${cleaner_cred_file} "[\"keyring\",\"eddsa\"]" "$eddsa_private_key"

    ################################################
    ##### Create the person
    ################################################
    result=$(createPerson "${cleaner_name}" ${cleaner_username} ${cleaner_email} ${eddsa_public_key})
    if [ "${do_debug} " == "true " ]
        then
            echo "DEBUG: $(date) -  result is: $(echo ${result} | jq '.')"
            # echo "$(date) - lochospital_id is ${lochospital_id}" 
        fi

    cleaner_id=$(echo ${result} | jq -r '.result.id')
    update_field ${cleaner_cred_file} "[\"id\"]" "$cleaner_id"
else
    echo "Data for cleaner seems to be already available"
fi

if [ "${do_init} " == "true " ] || [ ! -f "${init_file}" ]
then
    echo "$(date) - Creating units"
    ################################################################################
    ##### Create locations and units of measures
    ################################################################################
    eddsa=$(cat ${hosp_cred_file} | jq -r '.keyring.eddsa')
    result=$(createLocation ${eddsa} "${hospital_username}" "${hospital_name}" ${hospital_lat} ${hospital_long} "${hospital_addr}" ${hospital_note})
    lochospital_id=$(echo ${result} | jq -r '.result.location')
    if [ "${do_debug} " == "true " ]
    then
        echo "DEBUG: $(date) -  result is: ${result}"
        # echo "$(date) - lochospital_id is ${lochospital_id}" 
    fi
    echo "$(date) - Created location for ${hospital_name}, id: ${lochospital_id}"
    
    eddsa=$(cat ${cleaner_cred_file} | jq -r '.keyring.eddsa')
    result=$(createLocation ${eddsa} "${cleaner_username}" "${cleaner_name}" ${cleaner_lat} ${cleaner_long} "${cleaner_addr}" ${cleaner_note})
    loccleaner_id=$(echo ${result} | jq -r '.result.location')
    if [ "${do_debug} " == "true " ]
    then
        echo "DEBUG: $(date) -  result is: ${result}"
        # echo "$(date) - loccleaner_id is ${loccleaner_id}"
    fi
    echo "$(date) - Created location for ${cleaner_name}, id: ${loccleaner_id}"

    exit

    result=$(createUnit ${cleaner_seed} "u_piece" "om2:one")
    piece_unit=$(echo ${result} | jq -r '.result.unit')
    if [ "${do_debug} " == "true " ]
    then
        echo "DEBUG: $(date) -  result is: ${result}"
        # echo "$(date) - Piece unit is ${piece_unit}" 
    fi
    echo "$(date) - Created unit for gowns, id: ${piece_unit}"

    result=$(createUnit ${cleaner_seed} "kg" "om2:kilogram")
    mass_unit=$(echo ${result} | jq -r '.result.unit')
    if [ "${do_debug} " == "true " ]
    then
        echo "DEBUG: $(date) -  result is: ${result}"
        # echo "$(date) - Mass unit is ${mass_unit}" 
    fi
    echo "$(date) - Created unit for mass (kg), id: ${mass_unit}"

    result=$(createUnit ${cleaner_seed} "lt" "om2:litre")
    volume_unit=$(echo ${result} | jq -r '.result.unit')
    if [ "${do_debug} " == "true " ]
    then
        echo "DEBUG: $(date) -  result is: ${result}"
        # echo "$(date) - Volume unit is ${volume_unit}"
    fi
    echo "$(date) - Created unit for volume (litre), id: ${volume_unit}"
    
    result=$(createUnit ${hospital_seed} "h" "om2:hour")
    time_unit=$(echo ${result} | jq -r '.result.unit')
    if [ "${do_debug} " == "true " ]
    then
        echo "DEBUG: $(date) -  result is: ${result}"
        # echo "$(date) - Time unit is ${time_unit}" 
    fi
    echo "$(date) - Create unit for time (hour), id: ${time_unit}"

    # Save units to file
    jq -n "{lochospital_id: ${lochospital_id},  loccleaner_id: ${loccleaner_id}, piece_unit: ${piece_unit}, mass_unit: ${mass_unit}, volume_unit: ${volume_unit}, time_unit: ${time_unit}}" > ${init_file}
else
    echo "$(date) - Reading units from file ${init_file}"
    lochospital_id=$(cat ${init_file} | jq -r '.lochospital_id')
    loccleaner_id=$(cat ${init_file} | jq -r '.loccleaner_id')
    piece_unit=$(cat ${init_file} | jq -r '.piece_unit')
    mass_unit=$(cat ${init_file} | jq -r '.mass_unit')
    volume_unit=$(cat ${init_file} | jq -r '.volume_unit')
    time_unit=$(cat ${init_file} | jq -r '.time_unit')
    # if [ "${do_debug} " == "true " ]
    # then
    #     echo "$(date) - lochospital_id: ${lochospital_id},  loccleaner_id is ${loccleaner_id}, piece_unit: ${piece_unit}, mass_unit: ${mass_unit}, volume_unit: ${volume_unit}, time_unit: ${time_unit}"
    # fi
    echo "$(date) - Read location for ${hospital_name}, id: ${lochospital_id}"
    echo "$(date) - Read location for ${cleaner_name}, id: ${loccleaner_id}"
    echo "$(date) - Read unit for gowns, id: ${piece_unit}"
    echo "$(date) - Read unit for mass (kg), id: ${mass_unit}"
    echo "$(date) - Read unit for volume (litre), id: ${volume_unit}"
    echo "$(date) - Read unit for time (hour), id: ${time_unit}"

fi

exit

################################################################################
##### Create Resources (the owner is the cleaner for them all):
##### -gown (https://www.wikidata.org/wiki/Q89990310)
##### -soap to wash the gown (https://www.wikidata.org/wiki/Q34396)
##### -water to wash the gown (https://www.wikidata.org/wiki/Q283)
##### -cotton to sew the gown (https://www.wikidata.org/wiki/Q11457)
################################################################################
note='Specification for soap to be used to wash the gowns'
result=$(createResourceSpec ${cleaner_seed} "${mass_unit}" "Soap" "${note}" "https://www.wikidata.org/wiki/Q34396")
soap_spec_id=$(echo ${result} | jq -r '.result.specId')
if [ "${do_debug} " == "true " ]
then
    echo "DEBUG: $(date) -  result is: ${result}"
fi
echo "$(date) - Created ${note} with spec id: ${soap_spec_id}"

soap_trackid="soap-${RANDOM}"
result=$(createResource ${cleaner_seed} "${cleaner_id}" "Soap" ${soap_trackid} "${mass_unit}" 100 ${soap_spec_id})
event_id=$(echo ${result} | jq -r '.result.eventId')
soap_id=$(echo ${result} | jq -r '.result.resourceId')
if [ "${do_debug} " == "true " ]
then
    echo "DEBUG: $(date) -  result is: ${result}"
fi
echo "$(date) - Created 100 kg soap with tracking id: ${soap_trackid}, id: ${soap_id} owned by the cleaner, event id: ${event_id}"

note='Specification for water to be used to wash the gowns'
result=$(createResourceSpec ${cleaner_seed} "${volume_unit}" "Water" "${note}" "https://www.wikidata.org/wiki/Q283")
water_spec_id=$(echo ${result} | jq -r '.result.specId')
if [ "${do_debug} " == "true " ]
then
    echo "DEBUG: $(date) -  result is: ${result}"
fi
echo "$(date) - Created ${note} with spec id: ${water_spec_id}"

water_trackid="water-${RANDOM}"
result=$(createResource ${cleaner_seed} "${cleaner_id}" "Water" ${water_trackid} "${volume_unit}" 50 ${water_spec_id})
event_id=$(echo ${result} | jq -r '.result.eventId')
water_id=$(echo ${result} | jq -r '.result.resourceId')
if [ "${do_debug} " == "true " ]
then
    echo "DEBUG: $(date) -  result is: ${result}"
fi
echo "$(date) - Created 50 liters water with tracking id: ${water_trackid}, id: ${water_id} owned by the cleaner, event id: ${event_id}"

note='Specification for cotton to be used to sew the gowns'
result=$(createResourceSpec ${cleaner_seed} "${mass_unit}" "Cotton" "${note}" "https://www.wikidata.org/wiki/Q11457")
cotton_spec_id=$(echo ${result} | jq -r '.result.specId')
if [ "${do_debug} " == "true " ]
then
    echo "DEBUG: $(date) -  result is: ${result}"
fi
echo "$(date) - Created ${note} with spec id: ${cotton_spec_id}"

cotton_trackid="cotton-${RANDOM}"
result=$(createResource ${cleaner_seed} "${cleaner_id}" "Cotton" ${cotton_trackid} "${mass_unit}" 20 ${cotton_spec_id})
event_id=$(echo ${result} | jq -r '.result.eventId')
cotton_id=$(echo ${result} | jq -r '.result.resourceId')
if [ "${do_debug} " == "true " ]
then
    echo "DEBUG: $(date) -  result is: ${result}"
fi
echo "$(date) - Created 20 kg cotton with tracking id: ${cotton_trackid}, id: ${cotton_id} owned by the cleaner, event id: ${event_id}"

note='Specification for gowns'
result=$(createResourceSpec ${cleaner_seed} "${piece_unit}" "Gown" "${note}" "https://www.wikidata.org/wiki/Q89990310")
gown_spec_id=$(echo ${result} | jq -r '.result.specId')
if [ "${do_debug} " == "true " ]
then
    echo "DEBUG: $(date) -  result is: ${result}"
fi
echo "$(date) - Created ${note} with spec id: ${gown_spec_id}"

note='Specification for surgical operation'
result=$(createResourceSpec ${hospital_seed} "${time_unit}" "Surgical operation" "${note}" "https://www.wikidata.org/wiki/Q600236")
surgery_spec_id=$(echo ${result} | jq -r '.result.specId')
if [ "${do_debug} " == "true " ]
then
    echo "DEBUG: $(date) -  result is: ${result}"
fi
echo "$(date) - Created ${note} with spec id: ${surgery_spec_id}"

################################################################################
##### First we create the gown from the cotton
################################################################################
process_name='Process sew gown'
result=$(createProcess ${cleaner_seed} "${process_name}" "Sew gown process performed by ${cleaner_name}")
sewgownprocess_id=$(echo ${result} | jq -r '.result.processId')
if [ "${do_debug} " == "true " ]
then
    echo "DEBUG: $(date) -  result is: ${result}"
fi
echo "$(date) - Created process: ${process_name}, process id: ${sewgownprocess_id}"

event_note='consume cotton for sewing'
result=$(createEvent "consume" ${cleaner_seed} "${event_note}" ${cleaner_id} ${cleaner_id} ${mass_unit} 10 ${sewgownprocess_id} ${cotton_id})
event_id=$(echo ${result} | jq -r '.result.eventId')
if [ "${do_debug} " == "true " ]
then
    echo "DEBUG: $(date) -  result is: ${result}"
fi
echo "$(date) - Created event: ${event_note}, event id: ${event_id}, action consume 10 kg cotton as input for process: ${sewgownprocess_id}"

event_note='produce gown'
gown_trackid="gown-${RANDOM}"
result=$(createEvent "produce" ${cleaner_seed} "${event_note}" ${cleaner_id} ${cleaner_id} ${piece_unit} 1 ${sewgownprocess_id} ${gown_trackid} "Gown" ${gown_spec_id})
event_id=$(echo ${result} | jq -r '.result.eventId')
gown_id=$(echo ${result} | jq -r '.result.resourceId')
if [ "${do_debug} " == "true " ]
then
    echo "DEBUG: $(date) -  result is: ${result}"
fi
echo "$(date) - Created event: ${event_note}, event id: ${event_id}, action produce 1 gown with tracking id: ${gown_trackid}, id: ${gown_id} owned by the cleaner as output of process: ${sewgownprocess_id}"

# result=$(createResource ${cleaner_seed} "${cleaner_id}" "Gown" ${gown_trackid} "${piece_unit}" 1)
# event_id=$(echo ${result} | jq -r '.result.eventId')
# resourceIn_id=$(echo ${result} | jq -r '.result.resourceIn.id')
# gown_id=$(echo ${result} | jq -r '.result.resourceOut.id')
# if [ "${do_debug} " == "true " ]
# then
#     echo "DEBUG: $(date) -  result is: ${result}"
# fi
# echo "$(date) - Created 1 gown with tracking id: ${gown_trackid}, id: ${gown_id} owned by the cleaner, event id: ${event_id}"

################################################################################
##### First we transfer the gown from the owner to the hospital
##### The cleaner is still the primary accountable
################################################################################
transfer_note='Transfer gowns to hospital'
result=$(transferCustody ${cleaner_seed} ${cleaner_id} ${hospital_id} ${gown_id} ${piece_unit} 1 ${lochospital_id} "${transfer_note}")
event_id=$(echo ${result} | jq -r '.result.eventID')
gown_transferred_id=$(echo ${result} | jq -r '.result.transferredID')
if [ "${do_debug} " == "true " ]
then
    echo "DEBUG: $(date) -  result is: ${result}"
fi
echo "$(date) - Transferred custody of 1 gown to hospital with note: ${transfer_note}, event id: ${event_id}, gown tranferred id: ${gown_transferred_id}"

################################################################################
##### Perform the process at the hospital
################################################################################
process_name='Process Use Gown'
result=$(createProcess ${hospital_seed} "${process_name}" "Use gown process performed at ${hospital_name}")
useprocess_id=$(echo ${result} | jq -r '.result.processId')
if [ "${do_debug} " == "true " ]
then
    echo "DEBUG: $(date) -  result is: ${result}"
fi
echo "$(date) - Created process: ${process_name}, process id: ${useprocess_id}"

event_note='work perform surgery'
result=$(createEvent "work" ${hospital_seed} "${event_note}" ${hospital_id} ${hospital_id} ${time_unit} 80 ${useprocess_id} ${surgery_spec_id})
event_id=$(echo ${result} | jq -r '.result.eventId')
if [ "${do_debug} " == "true " ]
then
    echo "DEBUG: $(date) -  result is: ${result}"
fi
echo "$(date) - Created event: ${event_note}, event id: ${event_id}, action work 80 hours as input for process: ${useprocess_id}"

event_note='accept use for surgery'
result=$(createEvent "accept" ${hospital_seed} "${event_note}" ${hospital_id} ${hospital_id} ${piece_unit} 1 ${useprocess_id} ${gown_transferred_id})
event_id=$(echo ${result} | jq -r '.result.eventId')
if [ "${do_debug} " == "true " ]
then
    echo "DEBUG: $(date) -  result is: ${result}"
fi
echo "$(date) - Created event: ${event_note}, event id: ${event_id}, action accept 1 gown as input for process: ${useprocess_id}"

event_note='modify dirty after use'
result=$(createEvent "modify" ${hospital_seed} "${event_note}" ${hospital_id} ${hospital_id} ${piece_unit} 1 ${useprocess_id} ${gown_transferred_id})
event_id=$(echo ${result} | jq -r '.result.eventId')
if [ "${do_debug} " == "true " ]
then
    echo "DEBUG: $(date) -  result is: ${result}"
fi
echo "$(date) - Created event: ${event_note}, event id: ${event_id}, action modify 1 gown as output for process: ${useprocess_id}"

################################################################################
##### Transfer back to the owner (the cleaner)
################################################################################
transfer_note='Transfer gowns to cleaner'
result=$(transferCustody ${hospital_seed} ${hospital_id} ${cleaner_id} ${gown_transferred_id} ${piece_unit} 1 ${loccleaner_id} "${transfer_note}")
event_id=$(echo ${result} | jq -r '.result.eventID')
gown_transferred_back_id=$(echo ${result} | jq -r '.result.transferredID')

if [ "${do_debug} " == "true " ]
then
    echo "DEBUG: $(date) -  result is: ${result}"
fi
echo "$(date) - Transferred custody of 1 gown to cleaner with note: ${transfer_note}, event id: ${event_id}, gown transferred id: ${gown_transferred_back_id}"

################################################################################
##### Perform the process at the cleaner
################################################################################
process_name='Process Clean Gown'
result=$(createProcess ${cleaner_seed} "${process_name}" "Clean gown process performed at ${cleaner_name}")
cleanprocess_id=$(echo ${result} | jq -r '.result.processId')
if [ "${do_debug} " == "true " ]
then
    echo "DEBUG: $(date) -  result is: ${result}"
fi
echo "$(date) - Created process: ${process_name}, process id: ${cleanprocess_id}"

event_note='accept gowns to be cleaned'
result=$(createEvent "accept" ${cleaner_seed} "${event_note}" ${cleaner_id} ${cleaner_id} ${piece_unit} 1 ${cleanprocess_id} ${gown_transferred_back_id})
event_id=$(echo ${result} | jq -r '.result.eventId')
if [ "${do_debug} " == "true " ]
then
    echo "DEBUG: $(date) -  result is: ${result}"
fi
echo "$(date) - Created event: ${event_note}, event id: ${event_id}, action accept 1 gown as input for process: ${cleanprocess_id}"

event_note='consume water for the washing'
result=$(createEvent "consume" ${cleaner_seed} "${event_note}" ${cleaner_id} ${cleaner_id} ${volume_unit} 25 ${cleanprocess_id} ${water_id})
event_id=$(echo ${result} | jq -r '.result.eventId')
if [ "${do_debug} " == "true " ]
then
    echo "DEBUG: $(date) -  result is: ${result}"
fi
echo "$(date) - Created event: ${event_note}, event id: ${event_id}, action consume 25 liters water as input for process: ${cleanprocess_id}"

event_note='consume soap for the washing'
result=$(createEvent "consume" ${cleaner_seed} "${event_note}" ${cleaner_id} ${cleaner_id} ${mass_unit} 50 ${cleanprocess_id} ${soap_id})
event_id=$(echo ${result} | jq -r '.result.eventId')
if [ "${do_debug} " == "true " ]
then
    echo "DEBUG: $(date) -  result is: ${result}"
fi
echo "$(date) - Created event: ${event_note}, event id: ${event_id}, action consume 50 kg soap as input for process: ${cleanprocess_id}"

event_note='modify clean after washing'
result=$(createEvent "modify" ${cleaner_seed} "${event_note}" ${cleaner_id} ${cleaner_id} ${piece_unit} 1 ${cleanprocess_id} ${gown_transferred_back_id})
event_id=$(echo ${result} | jq -r '.result.eventId')
if [ "${do_debug} " == "true " ]
then
    echo "DEBUG: $(date) -  result is: ${result}"
fi
echo "$(date) - Created event: ${event_note}, event id: ${event_id}, action modify 1 gown as output of process: ${cleanprocess_id}"

echo "$(date) - Doing trace and track gown: ${gown_transferred_back_id}"
result=$(traceTrack ${gown_transferred_back_id} 10)

if [ "${do_debug} " == "true " ]
then
    echo "DEBUG: $(date) -  result is: ${result}"
fi
echo ${result} | jq -r '.result'

echo -e "Result from trace"
echo ${result} | jq -r '.result.trace[] | .id + " " + .__typename + " " + .name + " " + .note'

echo -e "Result from track"
echo ${result} | jq -r '.result.track[] | .id + " " + .__typename + " " + .name + " " + .note'


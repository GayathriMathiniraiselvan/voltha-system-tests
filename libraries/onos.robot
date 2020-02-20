# Copyright 2017-present Open Networking Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# onos common functions

*** Settings ***
Documentation     Library for various utilities
Library           SSHLibrary
Library           String
Library           DateTime
Library           Process
Library           Collections
Library           RequestsLibrary
Library           OperatingSystem

*** Keywords ***
Execute ONOS CLI Command
    [Arguments]    ${host}    ${port}    ${cmd}
    [Documentation]    Establishes an ssh connection to the onos contoller and executes a command
    ${conn_id}=    SSHLibrary.Open Connection    ${host}    port=${port}    timeout=300s
    SSHLibrary.Login    karaf    karaf
    @{result_values}    SSHLibrary.Execute Command    ${cmd}    return_rc=True
    ...    return_stderr=True    return_stdout=True
    ${output}    Set Variable    @{result_values}[0]
    Log    ${output}
    Should Be Empty    @{result_values}[1]
    Should Be Equal As Integers    @{result_values}[2]    0
    SSHLibrary.Close Connection
    [Return]    ${output}

Validate OLT Device in ONOS
    #    FIXME use volt-olts to check that the OLT is ONOS
    [Arguments]    ${serial_number}
    [Documentation]    Checks if olt has been connected to ONOS
    ${resp}=    Get Request    ONOS    onos/v1/devices
    ${jsondata}=    To Json    ${resp.content}
    Should Not Be Empty    ${jsondata['devices']}
    ${length}=    Get Length    ${jsondata['devices']}
    @{serial_numbers}=    Create List
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata['devices']}    ${INDEX}
        ${of_id}=    Get From Dictionary    ${value}    id
        ${sn}=    Get From Dictionary    ${value}    serial
        Run Keyword If    '${sn}' == '${serial_number}'    Exit For Loop
    END
    Should Be Equal As Strings    ${sn}    ${serial_number}
    [Return]    ${of_id}

Get ONU Port in ONOS
    [Arguments]    ${onu_serial_number}    ${olt_of_id}
    [Documentation]    Retrieves ONU port for the ONU in ONOS
    ${onu_serial_number}=    Catenate    SEPARATOR=-    ${onu_serial_number}    1
    ${resp}=    Get Request    ONOS    onos/v1/devices/${olt_of_id}/ports
    ${jsondata}=    To Json    ${resp.content}
    Should Not Be Empty    ${jsondata['ports']}
    ${length}=    Get Length    ${jsondata['ports']}
    @{ports}=    Create List
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata['ports']}    ${INDEX}
        ${annotations}=    Get From Dictionary    ${value}    annotations
        ${onu_port}=    Get From Dictionary    ${value}    port
        ${portName}=    Get From Dictionary    ${annotations}    portName
        Run Keyword If    '${portName}' == '${onu_serial_number}'    Exit For Loop
    END
    Should Be Equal As Strings    ${portName}    ${onu_serial_number}
    [Return]    ${onu_port}

Get FabricSwitch in ONOS
    [Documentation]    Returns of_id of the Fabric Switch in ONOS
    ${resp}=    Get Request    ONOS    onos/v1/devices
    ${jsondata}=    To Json    ${resp.content}
    Should Not Be Empty    ${jsondata['devices']}
    ${length}=    Get Length    ${jsondata['devices']}
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata['devices']}    ${INDEX}
        ${of_id}=    Get From Dictionary    ${value}    id
        ${type}=    Get From Dictionary    ${value}    type
        Run Keyword If    '${type}' == "SWITCH"    Exit For Loop
    END
    [Return]    ${of_id}

Verify Eapol Flows Added
    [Arguments]    ${ip}    ${port}    ${expected_flows}
    [Documentation]    Matches for number of eapol flows based on number of onus
    ${eapol_flows_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    flows -s -f ADDED | grep eapol | grep IN_PORT | wc -l
    Should Contain    ${eapol_flows_added}    ${expected_flows}

Verify Eapol Flows Added For ONU
    [Arguments]    ${ip}    ${port}    ${onu_port}
    [Documentation]    Verifies if the Eapol Flows are added in ONOS for the ONU
    ${eapol_flows_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    flows -s -f ADDED | grep eapol | grep IN_PORT:${onu_port}
    Should Not Be Empty    ${eapol_flows_added}

Verify ONU Port Is Enabled
    [Arguments]    ${ip}    ${port}    ${onu_port}
    [Documentation]    Verifies if the ONU port is enabled in ONOS
    ${onu_port_enabled}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ports -e | grep port=${onu_port}
    Log    ${onu_port_enabled}
    Should Not Be Empty    ${onu_port_enabled}

Verify ONU in AAA-Users
    [Arguments]    ${ip}    ${port}    ${onu_port}
    [Documentation]    Verifies that the specified onu_port exists in aaa-users output
    ${aaa_users}=    Execute ONOS CLI Command    ${ip}    ${port}    aaa-users | grep AUTHORIZED | grep ${onu_port}
    Should Not Be Empty    ${aaa_users}    ONU port ${onu_port} not found in aaa-users

Verify Number of AAA-Users
    [Arguments]    ${ip}    ${port}    ${expected_onus}
    [Documentation]    Matches for number of aaa-users authorized based on number of onus
    ##TODO: filter by onu serial number instead of count
    ${aaa_users}=    Execute ONOS CLI Command    ${ip}    ${port}    aaa-users | grep AUTHORIZED | wc -l
    Should Contain    ${aaa_users}    ${expected_onus}

Validate DHCP Allocations
    [Arguments]    ${ip}    ${port}    ${expected_onus}
    [Documentation]    Matches for number of dhcpacks based on number of onus
    ##TODO: filter by onu serial number instead of count
    ${allocations}=    Execute ONOS CLI Command    ${ip}    ${port}    dhcpl2relay-allocations | grep DHCPACK | wc -l
    Should Contain    ${allocations}    ${expected_onus}

Validate Subscriber DHCP Allocation
    [Arguments]    ${ip}    ${port}    ${onu_port}
    [Documentation]    Verifies that the specified subscriber is found in DHCP allocations
    ##TODO: Enhance the keyword to include DHCP allocated address is not 0.0.0.0
    ${allocations}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    dhcpl2relay-allocations | grep DHCPACK | grep ${onu_port}
    Should Not Be Empty    ${allocations}    ONU port ${onu_port} not found in dhcpl2relay-allocations

Device Is Available In ONOS
    [Arguments]    ${url}    ${dpid}
    [Documentation]    Validates the device exists and it available in ONOS
    ${rc}    ${json}    Run And Return Rc And Output    curl --fail -sSL ${url}/onos/v1/devices/${dpid}
    Should Be Equal As Integers    0    ${rc}
    ${rc}    ${value}    Run And Return Rc And Output    echo '${json}' | jq -r .available
    Should Be Equal As Integers    0    ${rc}
    Should Be Equal    'true'    '${value}'

Remove All Devices From ONOS
    [Arguments]    ${url}
    [Documentation]    Executes the device-remove command on each device in ONOS
    ${rc}    @{dpids}    Run And Return Rc And Output
    ...    curl --fail -sSL ${url}/onos/v1/devices | jq -r '.devices[].id'
    Should Be Equal As Integers    ${rc}    0
    ${count}=    Get length    ${dpids}
    FOR    ${dpid}    IN    @{dpids}
        ${rc}=    Run Keyword If    '${dpid}' != ''
        ...    Run And Return Rc    curl -XDELETE --fail -sSL ${url}/onos/v1/devices/${dpid}
        Run Keyword If    '${dpid}' != ''
        ...    Should Be Equal As Integers    ${rc}    0
    END

Get Bandwidth Details
    [Arguments]     ${bandwidth_profile_name}
    [Documentation]    Collects the bandwidth profile details for the given bandwidth profile and returns the maximum bandwidth
    ${banwidth_profile_values}=    Execute ONOS CLI Command    ${ip}    ${port}    bandwidthprofile ${bandwidth_profile_name}
    @{banwidth_profile_array}=     Split String     ${banwidth_profile_values}     ,
    FOR    ${value}    IN    @{banwidth_profile_array}
	@{parameter_value_pair}=      Split String     ${value}      =
	${cir_value}      Run Keyword and Ignore Error    Run Keyword If     '${parameter_value_pair[0]}' == 'committedInformationRate'    Set Variable    ${parameter_value_pair[1]}  
 	${cbs_value}      Run Keyword and Ignore Error    Run Keyword If     '${parameter_value_pair[0]}' == 'committedBurstSize'    Set Variable    ${parameter_value_pair[1]}  
	${eir_value}      Run Keyword and Ignore Error    Run Keyword If     '${parameter_value_pair[0]}' == 'exceededInformationRate'    Set Variable    ${parameter_value_pair[1]}  
	${ebs_value}      Run Keyword and Ignore Error    Run Keyword If     '${parameter_value_pair[0]}' == 'exceededBurstSize'    Set Variable    ${parameter_value_pair[1]}  
    END
    ${limiting_BW}=    Evaluate       ${cir_value}+${cbs_value}+${eir_value}+${ebs_value}
    [Return]    {${limiting_BW}

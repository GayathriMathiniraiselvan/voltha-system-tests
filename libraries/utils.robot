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
# robot test functions

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
Check CLI Tools Configured
    [Documentation]    Tests that use 'voltctl' and 'kubectl' should execute this keyword in suite setup
    # check voltctl and kubectl configured
    ${voltctl_rc}=    Run And Return RC    voltctl device list
    ${kubectl_rc}=    Run And Return RC    kubectl get pods
    Run Keyword If    ${voltctl_rc} != 0 or ${kubectl_rc} != 0    FATAL ERROR
    ...    VOLTCTL and KUBECTL not configured. Please configure before executing tests.

Send File To Onos
    [Documentation]    Send the content of the file to Onos to selected section of configuration
    ...   using Post Request
    [Arguments]    ${CONFIG_FILE}    ${section}
    ${Headers}=    Create Dictionary    Content-Type    application/json
    ${File_Data}=    OperatingSystem.Get File    ${CONFIG_FILE}
    Log    ${Headers}
    Log    ${File_Data}
    ${resp}=    Post Request    ONOS
    ...    /onos/v1/network/configuration/${section}    headers=${Headers}    data=${File_Data}
    Should Be Equal As Strings    ${resp.status_code}    200

Common Test Suite Setup
    [Documentation]    Setup the test suite
    # BBSim sanity test doesn't need these imports from other repositories
    Run Keyword If    ${external_libs}    Import Resource
    ...    ${CURDIR}/../../cord-tester/src/test/cord-api/Framework/Subscriber.robot
    Run Keyword If    ${external_libs}    Import Resource
    ...    ${CURDIR}/../../cord-tester/src/test/cord-api/Framework/OLT.robot
    Run Keyword If    ${external_libs}    Import Resource
    ...    ${CURDIR}/../../cord-tester/src/test/cord-api/Framework/DHCP.robot
    Run Keyword If    ${external_libs}    Import Resource
    ...    ${CURDIR}/../../cord-tester/src/test/cord-api/Framework/Kubernetes.robot
    Set Global Variable    ${KUBECTL_CONFIG}    export KUBECONFIG=%{KUBECONFIG}
    Set Global Variable    ${VOLTCTL_CONFIG}    export VOLTCONFIG=%{VOLTCONFIG}
    ${k8s_node_ip}=    Evaluate    ${nodes}[0].get("ip")
    ${k8s_node_user}=    Evaluate    ${nodes}[0].get("user")
    ${k8s_node_pass}=    Evaluate    ${nodes}[0].get("pass")
    Check CLI Tools Configured
    ${onos_auth}=    Create List    karaf    karaf
    ${HEADERS}    Create Dictionary    Content-Type=application/json
    Create Session    ONOS    http://${k8s_node_ip}:${ONOS_REST_PORT}    auth=${ONOS_AUTH}
    ${olt_ip}=    Evaluate    ${olts}[0].get("ip")
    ${olt_user}=    Evaluate    ${olts}[0].get("user")
    ${olt_pass}=    Evaluate    ${olts}[0].get("pass")
    ${olt_serial_number}=    Evaluate    ${olts}[0].get("serial")
    ${num_onus}=    Get Length    ${hosts.src}
    ${num_onus}=    Convert to String    ${num_onus}
    #send sadis file to onos
    ${sadis_file}=    Get Variable Value    ${sadis.file}
    Log To Console    \nSadis File:${sadis_file}
    Run Keyword Unless    '${sadis_file}' is '${None}'    Send File To Onos    ${sadis_file}    apps/
    Set Suite Variable    ${num_onus}
    Set Suite Variable    ${olt_serial_number}
    Set Suite Variable    ${olt_ip}
    Set Suite Variable    ${olt_user}
    Set Suite Variable    ${olt_pass}
    Set Suite Variable    ${k8s_node_ip}
    Set Suite Variable    ${k8s_node_user}
    Set Suite Variable    ${k8s_node_pass}
    @{container_list}=    Create List    adapter-open-olt    adapter-open-onu    voltha-api-server
    ...    voltha-ro-core    voltha-rw-core-11    voltha-rw-core-12    voltha-ofagent
    Set Suite Variable    ${container_list}
    ${datetime}=    Get Current Date
    Set Suite Variable    ${datetime}

WPA Reassociate
    [Documentation]    Executes a particular wpa_cli reassociate, which performs force reassociation
    [Arguments]    ${iface}    ${ip}    ${user}    ${pass}=${None}
    ...    ${container_type}=${None}    ${container_name}=${None}
    #Below for loops are used instead of sleep time, to execute reassociate command and check status
    FOR    ${i}    IN RANGE    70
        ${output}=    Login And Run Command On Remote System
        ...    wpa_cli -i ${iface} reassociate    ${ip}    ${user}
        ...    ${pass}    ${container_type}    ${container_name}
        ${passed}=    Run Keyword And Return Status    Should Contain    ${output}    OK
        Run Keyword If    ${passed}    Exit For Loop
    END
    FOR    ${i}    IN RANGE    70
        ${output}=    Login And Run Command On Remote System
        ...    wpa_cli status | grep SUCCESS    ${ip}    ${user}
        ...    ${pass}    ${container_type}    ${container_name}
        ${passed}=    Run Keyword And Return Status    Should Contain    ${output}    SUCCESS
        Run Keyword If    ${passed}    Exit For Loop
    END

Validate Authentication After Reassociate
    [Arguments]    ${auth_pass}    ${iface}    ${ip}    ${user}    ${pass}=${None}
    ...    ${container_type}=${None}    ${container_name}=${None}
    [Documentation]
    ...    Executes a particular reassociate request on the RG using wpa_cli.
    ...    auth_pass determines if authentication should pass
    WPA Reassociate    ${iface}    ${ip}    ${user}    ${pass}    ${container_type}    ${container_name}
    Run Keyword If    '${auth_pass}' == 'True'    Wait Until Keyword Succeeds    ${timeout}    2s
    ...    Check Remote File Contents    True    /tmp/wpa.log    authentication completed successfully
    ...    ${ip}    ${user}    ${pass}    ${container_type}    ${container_name}
    Run Keyword If    '${auth_pass}' == 'False'    Sleep    20s
    Run Keyword If    '${auth_pass}' == 'False'    Check Remote File Contents    False    /tmp/wpa.log
    ...    authentication completed successfully    ${ip}    ${user}    ${pass}
    ...    ${container_type}    ${container_name}

Send Dhclient Request To Release Assigned IP
    [Arguments]    ${iface}    ${ip}    ${user}    ${path_dhcpleasefile}    ${pass}=${None}
    ...    ${container_type}=${None}    ${container_name}=${None}
    [Documentation]    Executes a dhclient with option to release ip against a particular interface on the RG (src)
    ${result}=    Login And Run Command On Remote System
    ...    dhclient -nw -r ${iface} && rm ${path_dhcpleasefile}/dhclient.*    ${ip}    ${user}
    ...    ${pass}    ${container_type}    ${container_name}
    Log    ${result}
    #Should Contain    ${result}    DHCPRELEASE
    [Return]    ${result}

Check Remote File Contents For WPA Logs
    [Arguments]    ${file_should_exist}    ${file}    ${pattern}    ${ip}    ${user}    ${pass}=${None}
    ...    ${container_type}=${None}    ${container_name}=${None}    ${prompt}=~$
    [Documentation]    Checks for particular pattern count in a file
    ${result}=    Login And Run Command On Remote System
    ...    cat ${file} | grep '${pattern}' | wc -l    ${ip}    ${user}    ${pass}
    ...    ${container_type}    ${container_name}    ${prompt}
    [Return]    ${result}

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
Library           HttpLibrary.HTTP
Library           String
Library           DateTime
Library           Process
Library           Collections
Library           RequestsLibrary
Library           OperatingSystem

*** Keywords ***
Execute ONOS Command
    [Arguments]    ${host}    ${port}    ${cmd}
    [Documentation]    Establishes an ssh connection to the onos contoller and executes a command
    ${conn_id}=    SSHLibrary.Open Connection    ${host}    port=${port}    prompt=onos>    timeout=300s
    SSHLibrary.Login    karaf    karaf
    ${output}=    SSHLibrary.Execute Command    ${cmd}
    SSHLibrary.Close Connection
    [Return]    ${output}

Validate OLT Device in ONOS
    [Documentation]    Checks if olt has been connected to ONOS
    [Arguments]    ${serial_number}
    ${resp}=    Get Request    ONOS    onos/v1/devices
    ${jsondata}=    To Json    ${resp.content}
    Should Not Be Empty    ${jsondata['devices']}
    ${length}=    Get Length    ${jsondata['devices']}
    @{serial_numbers}=    Create List
    : FOR    ${INDEX}    IN RANGE    0    ${length}
    \    ${value}=    Get From List    ${jsondata['devices']}    ${INDEX}
    \    ${sn}=    Get From Dictionary    ${value}    serial
    \    ${of_id}=    Get From Dictionary    ${value}    id
    Should Be Equal As Strings    ${sn}    ${serial_number}
    Set Suite Variable    ${of_id}

Verify Eapol Flows Added
    [Arguments]    ${expected_onus}
    [Documentation]    Matches for number of eapol flows based on number of onus
    ${eapol_flows_added}=    Execute ONOS Command    flows -s -f ADDED | grep eapol | wc -l
    Should Contain    ${eapol_flows_added}    ${expected_onus}

Verify Number of AAA-Users
    [Arguments]    ${expected_onus}
    [Documentation]    Matches for number of aaa-users authorized based on number of onus
    ${aaa_users}=    Execute ONOS Command    aaa-users | grep AUTHORIZED | wc -l
    Should Contain    ${aaa_users}    ${expected_onus}

Validate DHCP Allocations
    [Arguments]    ${expected_onus}
    [Documentation]    Matches for number of dhcpacks based on number of onus
    ${allocations}=    Execute ONOS Command    dhcpl2relay-allocations | grep DHCPACK | wc -l
    Should Contain    ${allocations}    ${expected_onus}
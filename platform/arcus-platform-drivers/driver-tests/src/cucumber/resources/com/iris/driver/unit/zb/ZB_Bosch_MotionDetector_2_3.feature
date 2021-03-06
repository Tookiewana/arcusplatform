@Zigbee @Bosch @Motion @ReflexMotion
Feature: Test of the Bosch WP13 and WP11G Motion Detector ZigBee reflex driver
    
    These scenarios test the functionality of the Bosch WP13 and WP11G Motion Detector ZigBee driver.

    Background:
        Given the ZB_Bosch_MotionDetector_2_3.driver has been initialized
            And the device has endpoint 5

    @basic
    Scenario: Driver reports capabilities to platform.
        When a base:GetAttributes command is placed on the platform bus
        Then the driver should place a base:GetAttributesResponse message on the platform bus
            And the message's base:caps attribute list should be [ 'base', 'dev', 'devadv', 'devconn', 'devpow', 'mot', 'temp', 'devota' ]
            And the message's dev:devtypehint attribute should be Motion
            And the message's devadv:drivername attribute should be ZBBoschMotionDetector 
            And the message's devadv:driverversion attribute should be 2.3
            And the message's devpow:source attribute should be BATTERY
            And the message's devpow:linecapable attribute should be false
            And the message's devpow:backupbatterycapable attribute should be false
        Then both busses should be empty


############################################################
# General Driver Tests
############################################################

    @basic @added
    Scenario: Device added
        When the device is added
        Then the capability devpow:sourcechanged should be recent
            And the capability mot:motionchanged should be recent

    @basic @connected @timeout
    Scenario: Device Connected
        When the device is connected
        Then the driver should set timeout
        Then the driver should send pollcontrol setLongPollInterval
        Then the driver should send pollcontrol setShortPollInterval
        Then the driver should send temperaturemeasurement zclReadAttributes
        Then the driver should send diagnostics zclReadAttributes
        Then the driver should send iaszone zclReadAttributes
        Then the driver should send pollcontrol zclReadAttributes

    @basic @name
    Scenario Outline: Make sure driver allows device name to be set 
        When a base:SetAttributes command with the value of dev:name <value> is placed on the platform bus
        Then the platform attribute dev:name should change to <value>

        Examples:
          | value                    |
          | Motion                   |
          | "Kitchen Motion"         |
          | "Tom's Room"             |
          | "Bob & Sue's Room"       |


############################################################
# Event Handling Tests
############################################################

    # event doWriteIasCie
    Scenario: Event doWriteIasCie
        Given the driver variable writeIasCieCnt is 0 
        When event doWriteIasCie trigger
        Then the driver should send iaszone zclWriteAttributes
    
    # event doZoneEnroll
    Scenario: Event doZoneEnroll
        Given the driver variable zoneEnrollCnt is 0 
        When event doZoneEnroll trigger
        Then the driver should send iaszone zoneEnrollResponse

    # event powerClusterRead
    Scenario: Event powerClusterRead
        When event powerClusterRead trigger
        Then the driver should send Power zclReadAttributes

    # event CnfgPwrRpt
    Scenario: Event CnfgPwrRpt
        Given the driver variable CNFG_PWR_RPT is 0 
        When event CnfgPwrRpt trigger
        Then the driver should send Power 0x06
    
    # event CnfgTempRpt
    Scenario: Event CnfgTempRpt
        Given the driver variable CNFG_TEMP_RPT is 0
        When event CnfgTempRpt trigger
        Then the driver should send TemperatureMeasurement 0x06
        
    # event CnfgPollCrtl
    Scenario: Event CnfgPollCrtl
        Given the driver variable CNFG_POLL_CTRL is 0
        When event CnfgPollCrtl trigger
        Then the driver should send PollControl 0x02
        
    # event CnfgDiagRpt
    Scenario: Event CnfgDiagRpt
        Given the driver variable CNFG_DIAG_RPT is 0
        When event CnfgDiagRpt trigger
        Then the driver should send Diagnostics 0x06


############################################################
# Power Cluster Tests
############################################################

    # power.zclreadattributesresponse / zclreportattributes
    Scenario Outline: Power Read / Report
        Given the capability devpow:battery is 90
        When the device response with power <messageType> 
            And with parameter ATTR_BATTERY_VOLTAGE <voltage>
            And with parameter ATTR_BATTERY_VOLTAGE_MIN_THRESHOLD 24
            And send to driver
        # Then the capability devpow:battery should be <battery>
        Then the driver should place a base:ValueChange message on the platform bus
            And the message's devpow:battery attribute numeric value should be within delta 1.1 of <battery>
    
    Examples:
      | messageType               | voltage | battery |
      | zclreadattributesresponse | 24      | 0       |
      | zclreportattributes       | 27      | 50      |
      | zclreportattributes       | 30      | 100     |
      | zclreportattributes       | 31      | 100     |


############################################################
# Poll Control Cluster Tests
############################################################

    # pollcontrol.zclreadattributesresponse / zclreportattributes
    Scenario Outline: poll control read / report
        When the device response with pollcontrol <messageType>
        And with parameter ATTR_CHECKIN_INTERVAL 1
        And with parameter ATTR_LONG_POLL_INTERVAL 1
        And with parameter ATTR_SHORT_POLL_INTERVAL 1
        And send to driver

    Examples:
      | messageType               |
      | zclreadattributesresponse |
      | zclreportattributes       |

    # pollcontrol.CheckIn
    Scenario: poll control check in
        When the device response with pollcontrol checkin
            And send to driver
        Then the driver should send pollcontrol checkinresponse    
    
############################################################
# Temperature Cluster Tests
############################################################

    # temperaturemeasurement.zclreadattributesresponse / zclreportattributes
    Scenario Outline: Temperature measurement attribute reading and reporting
        When the device response with temperaturemeasurement <responseType>
            And with parameter ATTR_MEASURED_VALUE <value>
            And send to driver
        Then the driver should place a base:ValueChange message on the platform bus
            And the message's temp:temperature attribute numeric value should be within delta 0.01 of <result>

    Examples:
      | responseType              | value | result |
      | zclreadattributesresponse | 2757  | 27.57  |
      | zclreportattributes       | 2757  | 27.57  |


############################################################
# IAS Zone Cluster Tests
############################################################

    # iaszone.zclreadattributesresponse / zclreportattributes
    @IASZone
    Scenario Outline: Zone attribute reading and reporting
        When the device response with iaszone <responseType>
            And with parameter ATTR_ZONE_STATE 1
            And with parameter ATTR_ZONE_TYPE 1
            And with parameter ATTR_ZONE_STATUS 1
            And with parameter ATTR_IAS_CIE_ADDRESS 0123456789ABCDEF
            And send to driver

    Examples:
      | responseType              |
      | zclreadattributesresponse |
      | zclreportattributes       |

    # iaszone.zclwriteattributesresponse
    @IASZone
    Scenario Outline: Zone write attribute response
        Given the driver variable writeIasCieCnt is 0
        When the device response with iaszone zclwriteattributesresponse
            And with payload <payload>
            And send to driver
        Then the driver variable writeIasCieCnt should be <cntVar>

    Examples:
      | payload | cntVar | remarks                              |
      | 0x00    |    -1  | 0 = success, reset to -1             |
      | 0x70    |    -1  | 0x70 = Denied, must be factory reset |
      | 0xFF    |     0  | failed                               |
      | 0x01    |     0  | failed                               |

    # iaszone.ZoneEnrollRequest
    @IASZone
    Scenario: Zone request
        When the device response with iaszone zoneenrollrequest
            And with parameter zoneType 1
            And with parameter manufacturerCode 1
            And send to driver
        Then the driver should send iaszone zoneEnrollResponse

    # iaszone.zonestatuschangenotification - skip for now as this is handled via reflexes
    @Ignore
    @IASZone
    Scenario Outline: ZoneStatusChangeNotification
        Given the capability mot:motion is <prevState>
		When the device response with iaszone zonestatuschangenotification
			And with parameter zoneStatus <status>
			And with parameter extendedStatus 1
			And send to driver		
		Then the driver should place a base:ValueChange message on the platform bus
			And the message's mot:motion attribute should be <newState> 
	
	Examples:
		| prevState | status | newState |
		| NONE      |    1   | DETECTED |
		| DETECTED  |    0   | NONE     |


############################################################
# Diagnostics Cluster Tests
############################################################

    #diagnostics.zclreadattributesresponse / zclreportattributes
    Scenario Outline: diagnostics read / report response
        When the device response with diagnostics <messageType>
            And with parameter ATTR_LAST_MESSAGE_RSSI <rssi>
            And with parameter ATTR_LAST_MESSAGE_LQI <lqi>
            And send to driver
        Then the capability devconn:signal should be <signal> 
    
    Examples:
      | messageType               | rssi | lqi      | signal |
      | zclreadattributesresponse | 10   | 10       | 4      |
      | zclreportattributes       | 10   | INVALID  | 100    |


############################################################
# OTA Cluster Tests
############################################################

    # ota.zclreadattributesresponse
    @OTA
    Scenario: OTA read response
        Given the capability devota:targetVersion is 1
        When the device response with ota zclreadattributesresponse
            And with parameter ATTR_CURRENT_FILE_VERSION 1
            And send to driver
        Then the driver should place a base:ValueChange message on the platform bus
            And the capability devota:currentVersion should be 1
            And the capability devota:status should be COMPLETED
    
    # ota.querynextimagerequest
    @OTA
    Scenario: OTA query next image
        Given the capability devota:targetVersion is 1
        When the device response with ota querynextimagerequest
            And with parameter manufacturerCode 1
            And with parameter imageType 1
            And with parameter fileVersion 1
            And with header flags 1
            And send to driver
        Then the driver should place a base:ValueChange message on the platform bus
            And the capability devota:currentVersion should be 1
            And the capability devota:status should be COMPLETED
    
    #ota.imageblockrequest / imagePageRequest
    @OTA
    Scenario Outline: OTA image block / page
        Given the capability devota:status is IDLE
        When the device response with ota <messageType>
            And with parameter fileVersion 1
            And with parameter fileOffset 0
            And with header flags 1
            And send to driver 
        Then the driver should place a base:ValueChange message on the platform bus
            And the capability devota:targetVersion should be 1
            And the capability devota:status should be INPROGRESS
    
    Examples:
      | messageType       |
      | imageblockrequest |
      | imagePageRequest  |
    
    
    # ota.upgradeendrequest
    @OTA
    Scenario Outline: OTA upgrade end request
        When the device response with ota upgradeendrequest
            And with parameter status <status>
            And with parameter manufacturerCode 0
            And with parameter imageType 0
            And with parameter fileVersion 0
            And with header flags 1
            And send to driver 
        Then the driver should place a base:ValueChange message on the platform bus
            And the capability devota:status should be <result>

    Examples:
      | status | result    |
      |    0   | COMPLETED |
      |   -1   | FAILED    |


############################################################
# ZigBee Ack/Response Message Tests
############################################################

    # onZigbeeMessage(Zigbee.TYPE_ZCL) 
    Scenario Outline: default ZigbeeMessage processing
        When the device response with <cluster> <command>
            And send to driver

    Examples:
      | cluster | command | remarks                                |
      | 0x0020  | 0x0B    | CLUSTER_POLL_CONTROL, CMD_DFLT_RSP     |
      | 0x0500  | 0x0B    | CLUSTER_IAS_ZONE,     CMD_DFLT_RSP     |


    # onZigbeeMessage(Zigbee.TYPE_ZCL) 
    Scenario Outline: default ZigbeeMessage processing for Write/Config commands
        Given the driver variable <varName> is 1 
        When the device response with <cluster> <command>
            And with payload <payload>
            And send to driver
        Then the driver variable <varName> should be <varVal>

    Examples:
      | cluster | command | varName        | payload | varVal | remarks                                                                    |
      | 0x0020  | 0x04    | CNFG_POLL_CTRL |      0  |    -1  | CLUSTER_POLL_CONTROL, CMD_WRT_ATTR_RSP, 0=Success, reset counter to -1     |
      | 0x0020  | 0x04    | CNFG_POLL_CTRL |     -1  |     1  | CLUSTER_POLL_CONTROL, CMD_WRT_ATTR_RSP, -1=Fail, leave write counter as is |
      | 0x0001  | 0x07    | CNFG_PWR_RPT   |      0  |    -1  | CLUSTER_PWR_CNFG,     CMD_CNFG_RPT_RSP, 0=Success, reset counter to -1     |
      | 0x0001  | 0x07    | CNFG_PWR_RPT   |     -1  |     1  | CLUSTER_PWR_CNFG,     CMD_CNFG_RPT_RSP, -1=Fail, leave write counter as is |
      | 0x0402  | 0x07    | CNFG_TEMP_RPT  |      0  |    -1  | CLUSTER_TEMPERATURE,  CMD_CNFG_RPT_RSP, 0=Success, reset counter to -1     |
      | 0x0402  | 0x07    | CNFG_TEMP_RPT  |     -1  |     1  | CLUSTER_TEMPERATURE,  CMD_CNFG_RPT_RSP, -1=Fail, leave write counter as is |
      | 0x0B05  | 0x07    | CNFG_DIAG_RPT  |      0  |    -1  | CLUSTER_DIAGNOSTICS,  CMD_CNFG_RPT_RSP, 0=Success, reset counter to -1     |
      | 0x0B05  | 0x07    | CNFG_DIAG_RPT  |     -1  |     1  | CLUSTER_DIAGNOSTICS,  CMD_CNFG_RPT_RSP, -1=Fail, leave write counter as is |


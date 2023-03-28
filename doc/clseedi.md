# CLS.EEDI {#clseedi}

This is the documentation of the CLS.EEDI protocol. CLS.EEDI allows backend systems to exchange grid management related
data with local systems.

Please note that CLS.EEDI is under active development. All statements made in this documentation, in the schema files,
and in the examples can change at any time.

# Assumptions

- CLS connection is established
- Clocks are synchronized

# Protocol

There are two roles in the procotol:

1. The backend
2. The local device

The communication primitives are as follows:

- The backend sends `control` messages to the local device, the local device acknowledges them with an `ack` message
- The local device sends `state` messages to the backend
- Both sides can request an update of `control` or `state` respectively by sending a `read` message

@startuml
    participant Backend as B
    participant "Local Device" as LD

    alt control
        B -> LD: de.keo-connectivity.clseedi.control
        B <- LD: de.keo-connectivity.clseedi.ack
    else state
        B <- LD: de.keo-connectivity.clseedi.state
    else request state
        B -> LD: de.keo-connectivity.clseedi.read
        B <- LD: de.keo-connectivity.clseedi.state
    else request control
        B <- LD: de.keo-connectivity.clseedi.read
        B -> LD: de.keo-connectivity.clseedi.control
    end
@enduml

# Transport

MQTT shall be used to exchange messages between the backend and a local device. Two distinct topics shall be used to
transmit messages:

* one topic for messages from the backend to the local device
* one topic for messages from the local device to the backend

This specification does not dictate specific topics. **Close coordination between the backend and the operators of local
devices to find a suitable and matching scheme for topics is necessary for each deployment in which CLS.EEDI is to be
used**.

## Example topic scheme

Assuming we have a backend and two local devices:

* Device A with a unique identifier `A`
* Device B with a unique identifier `B`

The backend wants to send messages to either of those devices. When receiving messages the backend needs to be able to
identify which local device has sent the message. Topics can be chosen accordingly.

The backend subscribes to `clseedi/from-localdevice/+` to receive messages from both devices. For sending, the backend
can publish to `clseedi/to-localdevice/A` and `clseedi/to-localdevice/B`. Device A subscribes to
`clseedi/to-localdevice/A` and publishes to `clseedi/from-localdevice/A`. Device B subscribes to
`clseedi/to-localdevice/B` and publishes to `clseedi/from-localdevice/B`.

@startuml
rectangle "Device A" as A
rectangle "Device B" as B
cloud Backend

Backend  -l-> A : clseedi/to-localdevice/A
Backend  -r-> B : clseedi/to-localdevice/B
Backend <-l-  A : clseedi/from-localdevice/A
Backend <-r-  B : clseedi/from-localdevice/B
@enduml

# Data Model

The data model is defined in the form of JSON schemas. Each type (`control`, `state`, `read`) is defined in a distinct
file. Two additional files hold everything together:

* [message.schema.json](message.schema.json) defines the general structure of a CLS.EEDI message. It refers to the
  distinct payload schemas based on the message type.
* [definitions.schema.json](definitions.schema.json) defines reusable data types. The payload schemas refer to these
  type definitions.

The payload types are explained in the following sections.

## Control

A control message allows the backend to communicate its desires to the local device. Take a look at the schema and some
examples to get started:

* [schema](clseedi/de.keo-connectivity.clseedi.control.schema.json)
* examples
  * [Setting limits, tariff and trusting based on a certificate](clseedi/examples/de.keo-connectivity.clseedi.control.json)
  * [Trusting based on a certificate](clseedi/examples/de.keo-connectivity.clseedi.control.trust_certificate.json)
  * [Trusting based on just an SKI](clseedi/examples/de.keo-connectivity.clseedi.control.trust_ski.json)

The control payload can have the following properties:

* `limits` - a power consumption limit (LPC), a power production limit (LPP), or both
* `failsafes` - a failsafe power consumption limit (LPC), a failsafe power production limit (LPP), or both
* `tariffs` - time of use tariff information (TOUT)
* `trust` - a certificate or an SKI to be trusted for the SHIP connection the local device maintains

The distinct terms are explained in more detail in the following sections.

### Limits

Power limits are used to regulate the power consumption or production or both of local premises in terms of the EEBUS
use cases LPC and LPP.

A power limit always consists of three properties:

* `value` - the limit for active power in W as an integral number
* `active` - if set to true the limit is to be applied by the local device, if set to false no limit has to be applied
* `duration` - the time in seconds the limit is valid, starting at the time it is received

For example, a consumption limit of 5000 W that shall be applied for 3600 seconds (one hour) would be expressed like this:

```
{
    "limits": {
        "power": {
            "active": {
                "consumption": {
                    "value": 5000,
                    "active": true,
                    "duration": 3600
                },
            },
        },
    },
}
```

Limits always have a positive value and a positive duration.

The `active` flag can be used to deactivate a previously set limit.

### Failsafes

Failsafe limits allow the backend to define a safe state the local device goes into if EEBUS communication in the local
network is not possible. Semantically, failsafe values are the same as in the EEBUS use cases LPC and LPP. In CLS.EEDI a
failsafe value is expressed in W as an integral number. It represents active power.

In the EEBUS use cases LPC and LPP there is a heartbeat mechanism to monitor connectivity in the home area network and
trigger the failsafe state. Because CLS.EEDI is used for wide area communication there is no heartbeat mechanism.
Consequently, the failsafe state is only related to EEBUS communication in the home area network and not related to CLS
connectivity between the local device and the backend.

### Tariffs

Tariffs allow the backend to incentivise load shifting in terms of the EEBUS use case TOUT.

A tariff always consists of three properties:
* `toutSpecialization` - the combination of PoE (Price of Energy) and TF (Transmission Fee) for consumption or
  production
* `tiers` - the incentive tiers
* `slots` - the slots of the incentive table

All tariffs must satisfy the constraints stated in the `configuration` (see section "Configuration").

Please note that the data model for tariff information is under active development. Consider it to be highly
preliminary.

#### Tout Specialization

The property `toutSpecialization` is one of
* `consumptionPoe`
* `consumptionPoeTf`
* `consumptionTf`
* `productionPoe`
* `productionPoeTf`
* `productionTf`

Here is an example for this property:

```
{
    "toutSpecialization": "consumptionPoe"
}
```

#### Tiers

The property `tiers` is an array of
* `description` - the description of an incentive tier
* `label` - the label of an incentive tier
* `currency` - the currency of the incentive table, currently only EUR
* `tierId` - the Tier ID
* `incentives` - is an array of
 * `incentiveId` - Incentive ID
 * `incentive` - is one of
  * `absoluteCost`
  * `renewableEnergyPercentage`
  * `co2Emission`

Here is an example for this property:

```
[
    {
        "tierId": 0,
        "description": "tier description 0",
        "label": "tier label 0",
        "currency": "EUR",
        "incentives": [
            {
                "incentiveId": 0,
                "incentive": "absoluteCost"
            },
            {
                "incentiveId": 1,
                "incentive": "renewableEnergyPercentage"
            }
        ]
    },
    {
        "tierId": 1,
        "description": "tier description 1",
        "label": "tier label 1",
        "currency": "EUR",
        "incentives": [
            {
                "incentiveId": 0,
                "incentive": "absoluteCost"
            },
            {
                "incentiveId": 1,
                "incentive": "renewableEnergyPercentage"
            }
        ]
    }
]
```

#### Slots

The property `slots` always consists of three properties:
* `startTime` - Start time of the slot
* `endTime` - End time of the slot
* `tiers` - is an array of
 * `tierId` - ID of the tier
 * `lowerBoundaryValue` - lower boundary of the tier [W] as scaled number
 * `incentives` - is an array of
  * `incentiveId` - ID of the incentive
  * `value` - the value as scaled number

Here is an example for this property:

```
[
    {
        "startTime": 514862580,
        "endTime": 514862880,
        "tiers": [
            {
                "tierId": 0,
                "incentives": [
                    {
                        "incentiveId": 0,
                        "value": {
                            "number": 23,
                            "scale": -5
                        }
                    },
                    {
                        "incentiveId": 1,
                        "value": {
                            "number": 65,
                            "scale": 0
                        }
                    }
                ],
                "lowerBoundaryValue": {
                    "number": 0,
                    "scale": 0
                }
            },
            {
                "tierId": 1,
                "incentives": [
                    {
                        "incentiveId": 0,
                        "value": {
                            "number": 34,
                            "scale": 0
                        }
                    },
                    {
                        "incentiveId": 1,
                        "value": {
                            "number": 6,
                            "scale": 0
                        }
                    }
                ],
                "lowerBoundaryValue": {
                    "number": 2,
                    "scale": 3
                }
            }
        ]
    },
    {
        "startTime": 514862880,
        "endTime": 514863180,
        "tiers": [
            {
                "tierId": 0,
                "incentives": [
                    {
                        "incentiveId": 0,
                        "value": {
                            "number": 25,
                            "scale": -5
                        }
                    },
                    {
                        "incentiveId": 1,
                        "value": {
                            "number": 67,
                            "scale": 0
                        }
                    }
                ],
                "lowerBoundaryValue": {
                    "number": 0,
                    "scale": 0
                }
            },
            {
                "tierId": 1,
                "incentives": [
                    {
                        "incentiveId": 0,
                        "value": {
                            "number": 35,
                            "scale": 0
                        }
                    },
                    {
                        "incentiveId": 1,
                        "value": {
                            "number": 7,
                            "scale": 0
                        }
                    }
                ],
                "lowerBoundaryValue": {
                    "number": 3,
                    "scale": 3
                }
            }
        ]
    }
]
```

### Trust

The local device maintains one or more SHIP connections in the local network over which it executes EEBUS use cases. The
SHIP peer(s) will either be an energy management system (CEM) or one or more power consuming / producing device(s).

Establishing a SHIP connection requires mutual trust. If trust commissioning is not done locally, it can be performed by
the backend. The backend can send a list of full certificates or just SKIs (the SHA-1 hash of a certificate's public
key) to the local device. The local device will then trust the certificates or the SKIs. A new list fully replaces
existing trust.

A trust payload is an array. Each array item can have one of two properties:

* `certificate` - a full X.509 SHIP certificate in DER format, hex-encoded
* `ski` - just an SKI

Here are two examples:

* [Trusting based on a certificate](clseedi/examples/de.keo-connectivity.clseedi.control.trust_certificate.json)
* [Trusting based on just an SKI](clseedi/examples/de.keo-connectivity.clseedi.control.trust_ski.json)

SHIP trust setup usually happens just once, for example during the initial installation of the local devices. It is
therefore recommended to use this part of the control payload as rarely as possible.

## Acknowledgement

Upon receipt of a `control` message, the local device sends an `ack` message indicating whether the received message
is valid or not:

```
{
    "ack": true
}
```

Here, `true` means that all limits/failsafes/tariffs values contained in the message are valid.

Take a look at the schema and an example:

* [schema](clseedi/de.keo-connectivity.clseedi.ack.schema.json)
* [example](clseedi/examples/de.keo-connectivity.clseedi.ack.json)

## State

The data model for `state` messages consists of the following top-level properties:

* `limits` - the current status of the limits for consumption and production
* `failsafes` - the current failsafe values for consumption and production
* `tariffs` - energy prices over time
* `configuration` - the configuration of the local system
* `supportedEebusUseCases` - an array of EEBUS use cases the local device supports
* `metering` - measurements from grid connection point (*GCP)

The backend can read the current state of the local device by sending a `read` message (see section [Read](@ref Read)).
The local device is obliged to reply all data that is available to it, i.e. fill out all top-level properties of the
`state` message it can. All properties that are not present in the reply to a `read` message are expected to be
unavailable or unset on the local device. Consequently, a `state` message caused by a `read` message always represents
the complete state of the local device and overwrites all previous `state` message received from the local device.

Additionally, a local device can send unsolicited updates of its state. When notifying the state, not all top-level
properties have to be set. This allows the local device to notify only the properties that have changed. However, all
top-level properties that are set, have to reflect the complete current state of that top-level element.

Currently, it is not mandatory for a local device to notify state changes.

### Limits

The `limits` property in the `state` reflects the current limits in terms of the EEBUS use cases LPC and LPP.
The `active` flag indicates if the limit has been accepted and is active.
The `duration` indicates the remaining active time in seconds of the limit.

```
{
    "limits": {
        "consumption": {
            "value": 2000,
            "active": true,
            "duration": 3600
        }
    }
}
```

### Failsafes

The `failsafes` property in the `state` reflects the current failsafe values in terms of the EEBUS use cases LPC and
LPP.

```
{
    "failsafes": {
        "consumption": 0,
        "production": 0
    }
}
```

### Tariffs

The `tariffs` property shows the energy prices over time in terms of the EEBUS use case TOUT that are available to the
local device.

Please note that the data model for tariff information is under active development. Consider it to be highly
preliminary.

### Configuration

Information on the configuration of the local device. Currently only used to describe the maximum array sizes for the
incentive tables in terms of the EEBUS use case TOUT.

```
{
    "maxTiersPerSlot": 5,
    "maxIncentivesPerTier": 6,
    "maxSlots": 7
}
```

A local device that does not support tariff data shall set all three values to zero.

### Metering

Measurements from the grid connection point (GCP) in terms of the EEBUS use case MGCP. EEBUS devices can send a value
state for measurements to indicate an erroneous, or out of bounds measurement. Such values are not forwarded to
CLS.EEDI. For phase dependent measurements (current or voltage), an error on one phase leads to the removal of all phase
values.

```
{
    "frequency": {
        "value": {
            "number": 50,
            "scale": 0
        }
    },
    "voltage": {
        "a-n": {
            "value": {
                "number": 229,
                "scale": 0
            }
        },
        "b-n": {
            "value": {
                "number": 2305,
                "scale": -1
            }
        },
        "c-n": {
            "value": {
                "number": 231,
                "scale": 0
            }
        }
    },
    "momentaryCurrent": {
        "a": {
            "value": {
                "number": 43,
                "scale": -1
            }
        },
        "b": {
            "value": {
                "number": 0,
                "scale": 0
            }
        },
        "c": {
            "value": {
                "number": 0,
                "scale": 0
            }
        }
    },
    "momentaryPower": {
        "value": {
            "number": 2345,
            "scale": 0
        }
    }
}
```

### Demands

The forecast for power demands (consumption/production) from the local device in terms of the EEBUS
use case "PODF".


```
{
    "demands": {
        "power": {
            "active": {
                "slots": [
                    {
                        "startTime": 1676464774,
                        "duration": 1800,
                        "pMin": -400,
                        "pMax": 1200,
                        "pExp": 200
                    },
                    {
                        "startTime": 1676466574,
                        "duration": 10800,
                        "pMin": -400,
                        "pMax": 12000,
                        "pExp": 11234
                    },
                    {
                        "startTime": 1676477374,
                        "duration": 21600,
                        "pExp": 450
                    }
                ]
            }
        }
    }
}
```

### Supported EEBUS use cases

The `supportedEebusUseCases` property describes the EEBUS use cases supported by the local device. Supported values are
* `lpc` - Limitation of Power Consumption - a consumption limit and a consumption failsafe map to this use case
* `lpp` - Limitation of power production - a production limit and a production failsafe map to this use case
* `tout` - Time of Use Tariff - tariff data maps to this use case
* `mgcp` - Monitoring of Grid Connection Point - metering data maps to this use case
* `podf` - Power Demand Forecast - demands active data maps to this use case

```
[
    "lpc",
    "lpp",
    "tout",
    "mgcp",
    "podf"
]
```

Take a look at the schema and an example:

* [schema](clseedi/de.keo-connectivity.clseedi.state.schema.json)
* [example](clseedi/examples/de.keo-connectivity.clseedi.state.json)

The presence of an EEBUS use case in this array indicates that the use case can be performed with at least one local
device to which a SHIP connection exists. If this condition changes, for example because the SHIP connection fails or
the use case specific heartbeat is missing, the use case shall be removed from the array. A status message shall be sent
to the backend immediately after the change.

## Read {#Read}

Either side of the connection can send a `read` message to the other side. Upon receipt of a `read` message,

* the backend sends a `control` message with as much data as possible
* the local device sends a `state` message with as much data as possible

Take a look at the schema and an example:

* [schema](clseedi/de.keo-connectivity.clseedi.read.schema.json)
* [example](clseedi/examples/de.keo-connectivity.clseedi.read.json)

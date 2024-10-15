# CLS.EEDI {#clseedi}

This is the documentation of CLS.EEDI. It allows backend systems to exchange grid and energy management related data
with local systems at the grid connection point (GCP). CLS.EEDI is a convenient implementation of the use cases
standardized in VDE-AR 2829-6.

The following use cases are currently supported:
- Power limitation (LPC, LPP, POEN)
- Metering (MGCP, MPC)
- Tariffs (TOUT)
- Flexibility Provision (PODF)

CLS.EEDI requires an established TCP/IP based communication channel between backend systems and local systems.
Country-specific security requirements must be taken into account when establishing a secure communication channel.
It makes use of the MQTT protocol for the message transfer. CLS.EEDI uses JSON format to exchange messages.

# Requirements

- A communication channel between the backend system and the local device is established
  <span id="REQ-1"><a href="#REQ-1">[REQ-1]</a></span>
- Clocks are synchronized
  <span id="REQ-2"><a href="#REQ-2">[REQ-2]</a></span>

# Introduction

There are two roles defined in CLS.EEDI:

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

# Compatibility

CLS.EEDI follows the [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html) versioning model.

Both the protocol and schemas are compatible only within the same major version. No guarantees towards other major
versions are made.

The following rules SHALL be applied when receiving CLS.EEDI messages.

- Messages from devices implementing a different major version of CLS.EEDI SHALL be replied to with a negative
  acknowledgement message (`de.keo-connectivity.clseedi.ack`)
  <span id="REQ-3"><a href="#REQ-3">[REQ-3]</a></span>.
  To avoid an endless back and forth of acknowledgement messages, acknowledgement messages SHALL not be replied to with
  an acknowledgement message
  <span id="REQ-4"><a href="#REQ-4">[REQ-4]</a></span>.
- Key/value pairs in JSON objects, the name of which are unknown according to the CLS.EEDI specification implemented by
  the receiving device, SHALL be ignored
  <span id="REQ-5"><a href="#REQ-5">[REQ-5]</a></span>.
- Some strings with defined value sets are not modelled as `enum` in the JSON schema. When encountering an unknown value
  in such a string, the value SHALL be ignored.
  <span id="REQ-6"><a href="#REQ-6">[REQ-6]</a></span>.
  The following sections may define additional steps for specific strings.

The following rules SHALL be applied when introducing a new version of CLS.EEDI within the same major version.
- new key/value pairs SHALL NOT be marked `required`
- existing key/value pairs that are marked `required` SHALL NOT be removed
- the type of the value of an existing key/value pair SHALL NOT be changed

# Transport

MQTT SHALL be used to exchange messages between the backend and a local device
<span id="REQ-7"><a href="#REQ-7">[REQ-7]</a></span>.
Two distinct topics shall be used to transmit messages
<span id="REQ-8"><a href="#REQ-8">[REQ-8]</a></span>:

* one topic for messages from the backend to the local device
* one topic for messages from the local device to the backend

This specification does not dictate specific topics. **For any use of CLS.EEDI, close coordination between the backend
and the operators of the local devices is required to find a suitable and appropriate scheme for topics**.

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
cloud Broker
cloud Backend

A <-r-- Broker : clseedi/to-localdevice/A
A --r-> Broker : clseedi/from-localdevice/A

B <-l-- Broker : clseedi/to-localdevice/B
B --l-> Broker : clseedi/from-localdevice/B

Backend <-d-- Broker : clseedi/from-localdevice/+
Backend --d-> Broker : clseedi/to-localdevice/A \n clseedi/to-localdevice/B
@enduml

# Data Model

The data model is defined in the form of JSON schemas. Each type (`control`, `state`, `read`, `ack`) is defined in a
distinct file. Two additional files hold everything together:

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
  * [Setting a limit](clseedi/examples/de.keo-connectivity.clseedi.control_limits.json)
  * [Setting a failsafe](clseedi/examples/de.keo-connectivity.clseedi.control_failsafes.json)
  * [Setting a limit curve](clseedi/examples/de.keo-connectivity.clseedi.control_limits_envelope.json)
  * [Setting a tariff](clseedi/examples/de.keo-connectivity.clseedi.control.tariffs.json)
  * [Trusting based on a certificate](clseedi/examples/de.keo-connectivity.clseedi.control.trust_certificate.json)
  * [Trusting based on just an SKI](clseedi/examples/de.keo-connectivity.clseedi.control.trust_ski.json)
  * [Configure notifications](clseedi/examples/de.keo-connectivity.clseedi.control.notify.json)
  * [Configure schedules](clseedi/examples/de.keo-connectivity.clseedi.control.schedules.json)

The control payload can consist of the following top-level properties:

* `limits` - a power consumption limit (LPC), a power production limit (LPP) or power consumption/production curve (POEN)
* `failsafes` - a failsafe power consumption limit (LPC) or a failsafe power production limit (LPP)
* `fallbacks` - a fallback power curve (POEN)
* `tariffs` - time of use tariff information (TOUT)
* `trust` - certificates and/or SKIs to be trusted for the SHIP connections the local device maintains
* `notify` - configure notifications for sending measurement data
* `schedules` - configure control commands to be executed by the local device according to a schedule

In case that the control message is a reply to a `read` message (i.e. has a `relation`), all top-level properties can be
set, otherwise only a single top-level element is allowed
<span id="REQ-9"><a href="#REQ-9">[REQ-9]</a></span>.

When receiving a `control` message
- the top-level properties `tariffs`, `trust`, `notify` and `schedules` overwrite the previous state of those properties entirely
  <span id="REQ-10"><a href="#REQ-10">[REQ-10]</a></span>
- the elements `limits.power.active.consumption`, `limits.power.active.production`, `failsafes.power.active.consumption`
  and `failsafes.power.active.production` replace the previous state of that element entirely
  <span id="REQ-11"><a href="#REQ-11">[REQ-11]</a></span>

When receiving a `control` message, that is not a reply to a `read`, the local device SHALL send an
[acknowledgement message](@ref ack)
<span id="REQ-12"><a href="#REQ-12">[REQ-12]</a></span>.
A positive acknowledgement message means that the element contained in the message was valid and has been processed.

If an acknowledgment message for a `control` message is still pending and a subsequent `control` message for the same
top-level property is received, the backend should reply with a negative acknowledgement set to `"errorNumber": 3`
(command execution error).

The different top-level properties are explained in more detail in the following sections.

### Limits {#ControlLimits}

Power limits are used to regulate the power consumption or production or both of local premises in terms of the following
EEBUS use cases:
* LPC - an ad hoc limitation of consumption power
* LPP - an ad hoc limitation of production power
* POEN - a limitation curve(s) for limitation of consumption and production power over time

#### Ad-hoc limits (LPC/LPP) {#AdhocLimits}
A power limit consists of these properties:

* `value` - the limit for active power in W as an integer
* `active` - if set to true the limit is to be applied by the local device, if set to false no limit has to be applied
* `duration` - the time in seconds the limit is valid, starting at the time it is received (optional)

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

Limits always have a positive value. When a duration is specified, it must also be positive
<span id="REQ-13"><a href="#REQ-13">[REQ-13]</a></span>.
It is not allowed to send a consumption and a production limit in one message.
<span id="REQ-14"><a href="#REQ-14">[REQ-14]</a></span>

The local device SHALL reply with a positive acknowledgement message when the limit can be applied, i.e. the
controllable system has accepted it
<span id="REQ-15"><a href="#REQ-15">[REQ-15]</a></span>,
otherwise it SHALL reply with a negative acknowledgement message with `"errorNumber": 3` (command execution error)
<span id="REQ-16"><a href="#REQ-16">[REQ-16]</a></span>.
This can happen, for example when the controllable system rejects the limit. When no controllable system is attached
the local device SHALL reply with a negative acknowledgement message with `"errorNumber": 4` (command not supported).

The `active` flag can be used to deactivate a previously set limit.

If a scheduled limit is currently active, the backend SHALL NOT send an ad-hoc limit that is deactivated or allows higher consumption or production.
The local device SHALL reply with a negative acknowledgement message with `"errorNumber": 2` (protocol error) to an ad-hoc limit that is deactivated
or allows higher consumption or production than the currently active scheduled limit.


#### Limit curves (POEN) {#LimitCurves}
A power limit curve consists of these properties:
* `startTime` - the start time (in seconds since epoch) for the first slot
* `slots` - the slots of the curve

The `slots` consists of these properties:
* `pMin` - the minimal required power consumption/production (optional, if omitted, it is zero)
* `pMax` - the maximal allowed power consumption/production
* `duration` - the duration of the slot in seconds (mandatory for the very first slot, if omitted, the last set duration will be used for the slot)

All limit curves must satisfy the corresponding constraints (see section [constraints](@ref StateEnvelopeConstraints)).

### Failsafes {#ControlFailsafes}

Failsafe limits allow the backend to define a safe state the local device transitions to if EEBUS communication in the
local network is hindered. Semantically, failsafe values are the same as in the EEBUS use cases LPC and LPP. In CLS.EEDI
a failsafe value is expressed in W as an integer. It represents active power.

It is not allowed to send a consumption and a production failsafe in one message
<span id="REQ-17"><a href="#REQ-17">[REQ-17]</a></span>.

The local device SHALL reply with an positive acknowledgement message when the failsafe can be applied, i.e. the
controllable system has accepted it
<span id="REQ-18"><a href="#REQ-18">[REQ-18]</a></span>,
otherwise it SHALL reply with a negative acknowledgement message with `"errorNumber": 3` (command execution error)
<span id="REQ-19"><a href="#REQ-19">[REQ-19]</a></span>.
This can happen, when the controllable system rejects the failsafe value. When no controllable system is attached the
local device SHALL reply with a negative acknowledgement message with `"errorNumber": 4` (command not supported).

In the EEBUS use cases LPC and LPP there is a heartbeat mechanism to monitor connectivity in the home area network and
trigger the failsafe state. Because CLS.EEDI is used for wide area communication there is no heartbeat mechanism.
Consequently, the failsafe state is only related to EEBUS communication in the home area network and not related to CLS
connectivity between the local device and the backend. CLS.EEDI supports setting the failsafe limits only.

### Fallbacks {#ControlFallbacks}

Fallback curves are used in the POEN use case. They exist for the maximum consumption and the maximum production values.
A curve SHALL cover the whole day with the start time defined as 00:00:00Z (i.e. 12AM UTC). Gaps between slots are not allowed.

All fallback curves must satisfy the corresponding constraints (see section [constraints](@ref StateEnvelopeConstraints)).

```
{
  "fallbacks": {
      "power": {
          "active": {
              "envelope": {
                  "consumption": {
                      "slots": [
                          {
                              "pMax": 8000,
                              "duration": 39600
                          },
                          {
                              "pMax": 5000
                          },
                          {
                              "duration": 7200,
                              "pMax": 8000
                          }
                      ]
                  }
              }
          }
      }
  }
}
```

In this example, the consumption curve is defined with three slots:
* start time 00:00:00Z, duration of 39600s (11 hours), so the end time is 10:59:59Z, pMax: 8000W
* start time 11:00:00Z, duration is not set (therefore previous duration is used), so the end time is 21:59:59Z, pMax: 5000W
* start time 22:00:00Z, duration of 7200s (2 hours), so the end time is 23:59:59Z, pMax: 8000W

### Tariffs {#ControlTariffs}

Tariffs allow the backend to incentivize load shifting in terms of the EEBUS use case TOUT.

A tariff always consists of the following properties:
* `toutSpecialization` - defines which costs the tariff describes
* `tiers` - the incentive tiers
* `slots` - the slots of the incentive table
* `startTime` - the start time of the first slot

All tariffs must satisfy the corresponding constraints (see section [constraints](@ref StateTariffsConstraints)).

Here is an [example](clseedi/examples/de.keo-connectivity.clseedi.control.tariffs.json) demonstrating how to set a tariff.

@note The data model for tariff information is under active development. Consider it to be highly preliminary.

#### Tout Specialization

The following table defines what a tariff describes depending on the value of `toutSpecialization`.

`toutSpecialization` | Definition
-------------------- | -------------------------------------------------------------------------------------------------
`consumptionPoe`     | The tariff describes incentives for energy consumption. The cost is only made up of the price of energy.
`consumptionPoeTf`   | The tariff describes incentives for energy consumption. The cost is made up of the price of energy as well as the transmission fee.
`consumptionTf`      | The tariff describes incentives for energy consumption. The cost is only made up of the transmission fee.
`productionPoe`      | The tariff describes incentives for energy production. The cost is only made up of the price of energy.
`productionPoeTf`    | The tariff describes incentives for energy production. The cost is made up of the price of energy as well as the transmission fee.
`productionTf`       | The tariff describes incentives for energy production. The cost is only made up of the transmission fee.

If other values than the ones defined in this table are encountered, the complete `tariffs` element SHALL be ignored
<span id="REQ-20"><a href="#REQ-20">[REQ-20]</a></span>.

#### Tiers

The property `tiers` is an array of
* `description` - the description of an incentive tier
* `label` - the label of an incentive tier
* `currency` - the currency of the incentive table (SHALL be "EUR")
* `tierId` - the Tier ID
* `incentives` - is an array of
 * `incentiveId` - Incentive ID
 * `incentive` - the meaning of this incentive

The following table defines what an incentive describes depending on the value of `incentive`.

`incentive`                 | Definition
--------------------------- | ----------------------------------------------------------
`absoluteCost`              | this tier's cost in terms of absolute, monetary value
`renewableEnergyPercentage` | the relative amount of renewable energy used in this tier
`co2Emission`               | this tiers cost in terms of CO2 emissions

If other values than the ones defined in this table are encountered, the complete array entry in the `incentives`
element SHALL be ignored
<span id="REQ-21"><a href="#REQ-21">[REQ-21]</a></span>.

#### Slots

The property `slots` is an array of:
* `duration` - duration of the slot
* `tiers` - is an array of
 * `tierId` - ID of the tier
 * `lowerBoundaryValue` - lower boundary of the tier [W] as scaled number
 * `incentives` - is an array of
  * `incentiveId` - ID of the incentive
  * `value` - the value as scaled number
The first slot in the `slots` array SHALL contain the `duration` element <span id="REQ-XY"><a href="#REQ-XY">[REQ-XY]</a></span>.
For all subsequent slots the `duration` element MAY be omitted. If the `duration` element is omitted,
the last known `duration` value SHALL be applied. Every new `duration` value overrides the last known value
and SHALL be applied for the current slot and all subsequent slots until it is overridden again.

#### Incentive type vs specialization

Not every `incentive` makes sense and is allowed for every `toutSpecialization`. For the rules please refer to the following
compatibility table, where allowed combinations are marked with 'X'.

| `toutSpecialization` \ `incentive` | `absoluteCost` | `renewableEnergyPercentage` | `co2Emission`   |
| ---------------------------------- | :------------: | :-------------------------: | :-------------: |
| `consumptionPoe`                   |       X        |              X              |        X        |
| `consumptionPoeTf`                 |       X        |              X              |        X        |
| `consumptionTf`                    |       X        |                             |                 |
| `productionPoe`                    |       X        |                             |                 |
| `productionPoeTf`                  |       X        |                             |                 |
| `productionTf`                     |       X        |                             |                 |


### Trust

The local device maintains one or more SHIP connections in the local network over which it executes EEBUS use cases. The
SHIP peer(s) will either be an energy management system (CEM) or one or more power consuming / producing device(s).

Establishing a SHIP connection requires mutual trust. If trust commissioning is not done locally, it can be performed by
the backend. The backend can send a list of full certificates or just SKIs (the SHA-1 hash of a certificate's public
key) to the local device. The local device will then trust the certificates or the SKIs. A new list fully replaces
existing trust
<span id="REQ-22"><a href="#REQ-22">[REQ-22]</a></span>.

A trust payload is an array. Each array item can have one of two properties:

* `certificate` - a full X.509 SHIP certificate in DER format, hex-encoded
* `ski` - just an SKI

Here are two examples:

* [Trusting based on a certificate](clseedi/examples/de.keo-connectivity.clseedi.control.trust_certificate.json)
* [Trusting based on just an SKI](clseedi/examples/de.keo-connectivity.clseedi.control.trust_ski.json)

SHIP trust setup usually happens just once, for example during the initial installation of the local devices.

### Notify

Using this property, the backend can configure notifications of measurement values to be sent by the local device. To
configure these notifications, all following properties SHALL be set:

* `interval` - The seconds between notifications
* `endTime` - The timestamp indicating the end of the notification period
* `source` - The source type of measurement data

The following table defines what kind of measurement data the backed wants to be notified about, depending on the value of
`source`.

`source`     | Definition
------------ | ---------------------------------------------------------------------------------------------------------
gcp          | The backend wants to be notified about measurement data of the grid connection point of the premise.
controllable | The backend wants to be notified about aggregated measurement data of all controllable devices in the local network.

If other values than the ones defined in this table are encountered, no notifications for that source type SHALL be
sent
<span id="REQ-23"><a href="#REQ-23">[REQ-23]</a></span>.

The notifications SHALL be sent as a `state` message with measurement data
<span id="REQ-24"><a href="#REQ-24">[REQ-24]</a></span>.

To disable the notifications a control message with an empty notify element SHALL be sent
<span id="REQ-25"><a href="#REQ-25">[REQ-25]</a></span>.

Here is an [example](clseedi/examples/de.keo-connectivity.clseedi.control.notify.json) demonstrating how to configure
notifications.

### Schedules {#schedules}

The schedule functionality enables the backend to configure limits, which must be applied by the local device daily at the
specified time and for the specified duration. The following fields SHALL be set:

* `value` - The value of the limit in Watts
* `time` - The time of the day, when the limit must be applied by the local device, specified as a string in the ISO format in UTC
* `duration` - The duration in seconds for which the limit must be applied with a maximum of 24 hours

All schedules must satisfy the corresponding constraints (see section [constraints](@ref StateSchedulesConstraints)).

Upon receiving `schedules`, the local device SHALL respond if it is able to process them. If the local device does not
support `schedules`, it SHALL reply with `"errorNumber": 4` (command not supported). If the local device cannot process
schedules due to protocol violation or unsatisfied constraints, it SHALL reply with `"errorNumber": 2` (protocol error).
The following requirements apply to the schedules data:

* Schedules of the same type SHALL NOT overlap in time
* The `time` must be specified in Coordinated Universal Time (UTC)
* The `duration` SHALL NOT exceed 24 hours

Upon receipt of the schedules, the local device SHALL immediately invalidate the previous schedules and apply the new ones.

In case of a collision between a scheduled and an ad-hoc limit of the same type, the local device SHALL apply the more restrictive limit
for the duration of the collision.

Schedules rely on accurate date/clock synchronization.

Here is an [example](clseedi/examples/de.keo-connectivity.clseedi.control.schedules.json) demonstrating how to configure
schedules.


## Acknowledgement {#ack}

An acknowledgement message SHALL be sent as a reply by the local device to communicate whether the corresponding request
was valid and could be executed or not
<span id="REQ-26"><a href="#REQ-26">[REQ-26]</a></span>.

The following message types can cause an acknowledgement message:

- `de.keo-connectivity.clseedi.read`
- `de.keo-connectivity.clseedi.control`

If the `control` message is a reply to a `read` (i.e. has a `relation` filed) it SHALL NOT be acknowledged
<span id="REQ-27"><a href="#REQ-27">[REQ-27]</a></span>.

Other message types SHALL NOT cause acknowledgement messages
<span id="REQ-28"><a href="#REQ-28">[REQ-28]</a></span>.

The acknowledgement is represented by the `errorNumber` element in the acknowledgement message. A value greater than 0 indicates an error.

The following error numbers are defined:

`errorNumber` | Error type              | Description/Reason
------------- | ----------------------- | ----------------------------------------------------------------------------------------------
0             | Success                 | Success
1             | Schema error            | Invalid message, unable to parse, missing mandatory element
2             | Protocol error          | Unexpected message, e.g. state message with an unknown relation, version mismatch or empty control message
3             | Command execution error | The command could not be executed. There can be many reasons for that error, e.g. limit is rejected by the local device, certificate in trust is invalid or cannot be written, ...
4             | Command not supported   | The command is not supported, e.g. there is no controllable system which supports limitation or that understands tariffs (see also [supportedUseCases](@ref supportedUseCases))

Take a look at the schema and an example:

* [schema](clseedi/de.keo-connectivity.clseedi.ack.schema.json)
* [example](clseedi/examples/de.keo-connectivity.clseedi.ack.json)

## State {#State}

The data model for `state` messages consists of the following top-level properties:

* `limits` - the current status of the limits for consumption and production
* `failsafes` - the current failsafe values for consumption and production
* `fallbacks` - the fallback values for consumption and production curves
* `tariffs` - energy prices over time
* `constraints` - the constraints of the local system
* `supportedEebusUseCases` - an array of EEBUS use cases the local device supports
* `measurements` - measurement values from potentially different sources
* `demands` - power demand forecasts from the local device
* `timestamp` - the timestamp indicating the moment when the message was created
* `notify` - the current configuration of the notifications
* `schedules` - configured schedules

The backend can read the current state of the local device by sending a `read` message (refer to the [Read](@ref Read)
section for details). In the case of a `read` message with empty `parameters`, all properties that are not present in
the reply are expected to be unavailable or unset on the local device. Consequently, a `state` message caused by a
`read` message with empty `parameters` always represents the complete state of the local device and overwrites all
previous `state` messages received from the local device
<span id="REQ-29"><a href="#REQ-29">[REQ-29]</a></span>.

The backend can configure which parts of the local device's state it wants to receive, using the `parameters` property.

When receiving a `read` message with non-empty `parameters` ("selective read") the local device SHALL reply with a
`state` message
<span id="REQ-30"><a href="#REQ-30">[REQ-30]</a></span>.
All top-level properties that are listed in `parameters` for which the local device does not have data, SHALL NOT be
present in the `state` message
<span id="REQ-31"><a href="#REQ-31">[REQ-31]</a></span>.
All top-level properties that are listed in `parameters` for which the local device does have data, SHALL be present in
the `state` message
<span id="REQ-32"><a href="#REQ-32">[REQ-32]</a></span>.
All top-level properties that are not listed in the `parameters` SHALL NOT be present in the `state` message.
<span id="REQ-33"><a href="#REQ-33">[REQ-33]</a></span>.

When receiving a `state` message that was caused by a `read` message with non-empty `parameters`,  all top-level
properties that are present in the `state` message overwrite all previous state of that top-level property
<span id="REQ-34"><a href="#REQ-34">[REQ-34]</a></span>.
All top-level properties that were listed in `parameters` that are not present in the `state` message are expected to
not be available anymore at the local device.
<span id="REQ-35"><a href="#REQ-35">[REQ-35]</a></span>.

Additionally, a local device can send unsolicited updates of its state. When notifying the state, not all top-level
properties have to be set. This allows the local device to notify only the properties that have changed. When any of the
`limits`, `failsafes`, `tariffs`, `constraints`, `supportedEebusUseCases`, `demands`, `notify`, `trust`, `fallbacks` or
`schedules` top-level property are set, they SHALL reflect the complete current state of those top-level properties
<span id="REQ-36"><a href="#REQ-36">[REQ-36]</a></span>.
When the `measurements` top-level property is set, every array element SHALL reflect the complete current state of the
measurement source represented by that `id`.
<span id="REQ-37"><a href="#REQ-37">[REQ-37]</a></span>.

Take a look at the schema and an example:

* [schema](clseedi/de.keo-connectivity.clseedi.state.schema.json)
* [example](clseedi/examples/de.keo-connectivity.clseedi.state.json)


### Limits {#StateLimits}

The `limits` property in the `state` reflects the current power limits in terms of the EEBUS use cases LPC, LPP for ad-hoc limitation
and in terms of EEBUS use case POEN for limitation curves.

#### Ad-hoc limits (LPC/LPP)
The `active` flag indicates if the power limit has been accepted and is active.
The `duration` indicates the remaining active time in seconds of the power limit
<span id="REQ-38"><a href="#REQ-38">[REQ-38]</a></span>.

```
{
    "limits": {
        "power": {
            "active": {
                "consumption": {
                    "value": 2000,
                    "active": true,
                    "duration": 3600
                }
            }
        }
    }
}
```

#### Limit curves (POEN)
When the use case POEN is available, the existing limit curve(s) can be found in the `envelope` element.
```
{
    "limits": {
        "power": {
            "active": {
                "envelope": {
                    "consumption": {
                        "startTime": 1719310350,
                        "slots": [
                            {
                                "pMin": 400,
                                "pMax": 4000,
                                "duration": 900
                            },
                            {
                                "pMax": 2000
                            },
                            {
                                "duration": 19800,
                                "pMin": 200,
                                "pMax": 1000
                            }
                        ]
                    }
                }
            }
        }
    }
}
```

### Failsafes {#StateFailsafes}

The `failsafes` property in the `state` reflects the current failsafe values in terms of the EEBUS use cases LPC and
LPP.

```
{
    "failsafes": {
        "power": {
            "active": {
                "consumption": 0,
                "production": 0
            }
        }
    }
}
```

### Fallbacks {#StateFallbacks}

The `fallbacks` property in the `state` reflects the current values for the fallback curves in terms of the EEBUS use case POEN.

```
{

    "fallbacks": {
        "power": {
            "active": {
                "envelope": {
                    "consumption": {
                        "slots": [
                            {
                                "pMax": 8000,
                                "duration": 39600
                            },
                            {
                                "pMax": 5000
                            },
                            {
                                "duration": 7200,
                                "pMax": 8000
                            }
                        ]
                    }
                }
            }
        }
    }
}
```

The curve for production follows the same rules.


### Tariffs {#StateTariffs}

The `tariffs` property shows the energy prices over time in terms of the EEBUS use case TOUT that are available to the
local device.

This [example](clseedi/examples/de.keo-connectivity.clseedi.state.tariffs.json) demonstrates how the local device
communicates the tariff it has received before.

Please note that the data model for tariff information is under active development. Consider it to be highly
preliminary.

### Constraints {#StateConstraints}

The local device may define constraints, which must be considered in the control messages, sent by the backend.
Constraints may not be changed by the backend. The local device SHALL NOT set constraints if relevant control is not supported and SHALL NOT support an use case when mandatory constraints are missing.
For example if tariffs are not supported by the local device, the local device SHALL NOT set tariff constraints in the state message <span id="REQ-39"><a href="#REQ-39">[REQ-39]</a></span>.
When a control message violates a constraint, the message SHALL be rejected with a negative acknowledgement set to "errorNumber": 2 (protocol error).

#### Tariffs {#StateTariffsConstraints}

Information on the tariffs constraints of the local device. Currently only used to describe the maximum array sizes for
the incentive tables and the specializations used in terms of the EEBUS use case TOUT.

This [example](clseedi/examples/de.keo-connectivity.clseedi.state.tariffsConstraints.json) demonstrates how the local
device communicates the tariff constraints.

#### Envelope {#StateEnvelopeConstraints}

Possible constraints for use case POEN:

Constraint       | Semantics of Value
---------------- | ---------------------------------------------------------
minSlots         | Minimal required slots
maxSlots         | Maximal allowed slots (mandatory)
pValueMin        | Minimal allowed power value (mandatory)
pValueMax        | Maximal allowed power value (mandatory)
pValueStepSize   | Step size of the power value
durationStepSize | Step size of the duration

Here is an [example](clseedi/examples/de.keo-connectivity.clseedi.state_envelope.json) showing constraints for all curves.

#### Schedules {#StateSchedulesConstraints}

Local devices may define the following constraints for control message with schedules:

Constraint       | Semantics of Value
---------------- | ---------------------------------------------------------
maxSchedules     | Maximal allowed number of schedules
timeResolution   | Time resolution in seconds

The `timeResolution` specifies the precision with which the local device applies scheduled commands (both time and duration).
For example if the timeResolution is defined to be 60 seconds, the local devices guarantees to apply schedule commands not
earlier than 30 seconds before and not later than 30 seconds after the scheduled time.

The duration of the schedules command SHALL NOT be shorter than the `timeResolution`. The local device SHALL reject the
schedule with `"errorNumber": 2` (protocol error) if the duration is shorter than the `timeResolution`.

Here is an [example](clseedi/examples/de.keo-connectivity.clseedi.state.schedulesConstraints.json) showing constraints for schedules.


### Measurements {#StateMeasurements}

The measurement values communicated via CLS.EEDI always represent the latest measurements the local device has received
from the corresponding measurement source
<span id="REQ-40"><a href="#REQ-40">[REQ-40]</a></span>.
If a measurement source disappears, the measurement values of that source SHALL be removed in CLS.EEDI
<span id="REQ-41"><a href="#REQ-41">[REQ-41]</a></span>.
Measurement values that are indicated to be invalid (e.g. out of range) by the measurement source SHALL be removed in
CLS.EEDI
<span id="REQ-42"><a href="#REQ-42">[REQ-42]</a></span>.
However, the technology used to obtain measurements from the measurement source, may not support communicating invalid
values.

The array `measurements` can contain multiple sets of measurement values. Each JSON object in the array represents one
set of measurement values. Each set of measurement values consists of

- a unique ID representing the set of measurement values
- a type describing the source of the measurement values
- the actual measurement values

Currently, the following measurement device types are defined.

`source`     | Definition
------------ | ---------------------------------------------------------
gcp          | Represents the grid connection point of a premise.
controllable | Represents all controllable devices in the local network.

If other values than the ones defined in this table are encountered, the complete set of measurements for this source
SHALL be ignored
<span id="REQ-43"><a href="#REQ-43">[REQ-43]</a></span>.

The following table shows the data points that can be communicated.

JSON Path        | Semantics of Value
---------------- | -----------------------------------------------------------------------------------------------------
power.total      | Momentary total power consumption/production as defined by the EEBUS use cases MGCP and MPC
power.phases.a   | Momentary power consumption/production on phase A as defined by the EEBUS use case MPC
power.phases.b   | Momentary power consumption/production on phase B as defined by the EEBUS use case MPC
power.phases.c   | Momentary power consumption/production on phase C as defined by the EEBUS use case MPC
energy.consumed  | Total consumed energy as defined by the EEBUS use cases MGCP and MPC
energy.produced  | Total produced energy as defined by the EEBUS use cases MGCP and MPC
current.a        | Momentary current consumption/production on phase A as defined by the EEBUS use cases MGCP and MPC
current.b        | Momentary current consumption/production on phase B as defined by the EEBUS use cases MGCP and MPC
current.c        | Momentary current consumption/production on phase C as defined by the EEBUS use cases MGCP and MPC
voltage.a-n      | Voltage between phase A and neutral as defined by the EEBUS use cases MGCP and MPC
voltage.b-n      | Voltage between phase B and neutral as defined by the EEBUS use cases MGCP and MPC
voltage.c-n      | Voltage between phase C and neutral as defined by the EEBUS use cases MGCP and MPC
frequency        | Frequency as defined by the EEBUS use cases MGCP and MPC

If notifications have been configured by the backend via the `notify` property of the `control` message, the local
device SHALL periodically send `state` messages with the `measurements` property set
<span id="REQ-44"><a href="#REQ-44">[REQ-44]</a></span>.

Here is an [example](clseedi/examples/de.keo-connectivity.clseedi.state.measurements.json) showing the observed state
of the measurement data.

### Demands {#StateDemands}

Using the `demands` property the local device can communicate forecasts for predicted power consumption and production
in terms of the EEBUS use case PODF to the backend.

A power demand forecast always consists of the following properties:
* `slots` - the array of slots with demand forecast
* `startTime` - the start time of the first slot

The property `slots` is an array of:
* `duration` - duration of the slot
* `pMin` - is minimal expected power consumption for the given time slot
* `pMax` - is maximal expected power consumption for the given time slot
* `pExp` - is the expected power consumption for the given time slot
The first slot in the `slots` array SHALL contain the `duration` element <span id="REQ-XY"><a href="#REQ-XY">[REQ-XY]</a></span>.
For all subsequent slots the `duration` element MAY be omitted. If the `duration` element is omitted,
the last known `duration` value SHALL be applied. Every new `duration` value overrides the last known value
and SHALL be applied for the current slot and all subsequent slots until it is overridden again.

This [example](clseedi/examples/de.keo-connectivity.clseedi.state.demands.json) demonstrates how a local device can
communicate its power demand forecast.

Please note that the data model for forecast information is under active development. Consider it to be highly
preliminary.

### Supported EEBUS use cases {#supportedUseCases}

The `supportedEebusUseCases` property describes the EEBUS use cases supported by the local device. The presence of an
EEBUS use case in this array indicates that the use case or equivalent functionality is available in the local network.
If the functionality for a use case is no longer available the use case SHALL be removed from the array
<span id="REQ-45"><a href="#REQ-45">[REQ-45]</a></span>.
A `state` message including the `supportedEebusUseCases` property SHALL be sent to the backend immediately after the
change
<span id="REQ-46"><a href="#REQ-46">[REQ-46]</a></span>.

The following table defines which functionality is represented how in the `supportedEebusUseCases` element.

`supportedEebusUseCases` | Definition
--------------------     | -----------------------------------------------------------------------------------------------------
`lpc`                    | Limitation of Power Consumption - a consumption limit and a consumption failsafe map to this use case
`lpp`                    | Limitation of Power Production - a production limit and a production failsafe map to this use case
`tout`                   | Time of Use Tariff - tariff data maps to this use case
`mgcp`                   | Monitoring of Grid Connection Point - measurement data maps to this use case
`mpc`                    | Monitoring of Power Consumption - measurement data maps to this use case
`podf`                   | Power Demand Forecast - demands active data maps to this use case
`poen`                   | Power Envelope - envelope data in limits and fallbacks map to this use case

If other values than the ones defined in this table are encountered, the array entry SHALL be ignored
<span id="REQ-47"><a href="#REQ-47">[REQ-47]</a></span>.

The following top-level properties of `control` messages can be expected to be handled by local device when the use case is present:
* `lpc` - [limits](@ref ControlLimits) and [failsafes](@ref ControlFailsafes)
* `lpp` - [limits](@ref ControlLimits) and [failsafes](@ref ControlFailsafes)
* `tout` - [tariffs](@ref ControlTariffs)
* `poen` - [limits](@ref LimitCurves) and [fallbacks](@ref ControlFallbacks)

The following top-level properties of `state` messages can be expected to be set by the local network when the use case is present:
* `lpc` - [limits](@ref StateLimits) and [failsafes](@ref StateFailsafes)
* `lpp` - [limits](@ref StateLimits) and [failsafes](@ref StateFailsafes)
* `tout` - [tariffs](@ref StateTariffs), [constraints](@ref StateTariffsConstraints)
* `mgcp` - [measurements](@ref StateMeasurements)
* `podf` - [demands](@ref StateDemands)
* `mpc` - [measurements](@ref StateMeasurements)
* `poen` - [constraints](@ref StateEnvelopeConstraints), [limits](@ref LimitCurves) and [fallbacks](@ref StateFallbacks)

### Notify

The current configuration of the notifications.

Here is an [example](clseedi/examples/de.keo-connectivity.clseedi.state.notify.json) demonstrating the observed state
of the configured notifications.

### Schedules {#StateSchedules}

The current configuration of the schedules. Every valid schedule entry with the associated `value`, `time` and
`duration` is displayed.

Here is an [example](clseedi/examples/de.keo-connectivity.clseedi.state.schedules.json) demonstrating the observed state
of the configured schedules.

## Read {#Read}

Either side of the connection can send a `read` message to the other side. Upon receiving a `read` message,

* the backend sends a `control` message <span id="REQ-48"><a href="#REQ-48">[REQ-48]</a></span>.
* the local device sends a `state` message <span id="REQ-49"><a href="#REQ-49">[REQ-49]</a></span>.

The backend can configure the specific information it wants to receive from the local device by specifying the desired
top-level [state](@ref State) properties in the `read` message. By selectively choosing the parameters, the backend can
effectively filter the data and retrieve only the relevant information. Alternatively, if the `read` message is sent
with an empty parameter list, it indicates that the backend intends to receive all available information up to the
current moment.

The following list shows the top-level properties from which to retrieve information:
* `limits`
* `failsafes`
* `fallbacks`
* `tariffs`
* `constraints`
* `supportedEebusUseCases`
* `measurements`
* `demands`
* `notify`
* `schedules`

The local device cannot configure the information it wants to receive. Instead, upon sending a `read` message, the
backend SHALL send all the information accumulated up to that moment in a `control` message
<span id="REQ-50"><a href="#REQ-50">[REQ-50]</a></span>.

Take a look at the schema and examples:

* [schema](clseedi/de.keo-connectivity.clseedi.read.schema.json)
* [example](clseedi/examples/de.keo-connectivity.clseedi.read.json)
* [selective read example](clseedi/examples/de.keo-connectivity.clseedi.read.selective.json)

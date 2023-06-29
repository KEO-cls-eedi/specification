# CLS.EEDI {#clseedi}

This is the documentation of the CLS.EEDI protocol. CLS.EEDI allows backend systems to exchange grid management related
data with local systems.

# Requirements

- A communication channel between the backend system and the local device is established
- Clocks are synchronized

# Protocol

There are two roles in the protocol:

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
  acknowledgement message (`de.keo-connectivity.clseedi.ack`). To avoid an endless back and forth of acknowledgement
  messages, acknowledgement messages SHALL not be replied to with an acknowledgement message.
- Key/value pairs in JSON objects, the name of which are unknown according to the CLS.EEDI specification implemented by
  the receiving device, SHALL be ignored.
- Some strings with defined value sets are not modelled as `enum` in the JSON schema. When encountering an unknown value
  in such a string, the value SHALL be ignored. The following sections may define additional steps for specific strings.

The following rules SHALL be applied when introducing a new version of CLS.EEDI within the same major version.
- new key/value pairs SHALL NOT be marked `required`
- existing key/value pairs that are marked `required` SHALL NOT be removed
- the type of the value of an existing key/value pair SHALL NOT be changed

# Transport

MQTT SHALL be used to exchange messages between the backend and a local device. Two distinct topics shall be used to
transmit messages:

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
  * [Trusting based on a certificate](clseedi/examples/de.keo-connectivity.clseedi.control.trust_certificate.json)
  * [Trusting based on just an SKI](clseedi/examples/de.keo-connectivity.clseedi.control.trust_ski.json)
  * [Configure notifications](clseedi/examples/de.keo-connectivity.clseedi.control.notify.json)

The control payload can consist of the following top-level properties:

* `limits` - a power consumption limit (LPC) or a power production limit (LPP)
* `failsafes` - a failsafe power consumption limit (LPC) or a failsafe power production limit (LPP)
* `trust` - certificates and/or SKIs to be trusted for the SHIP connections the local device maintains
* `notify` - configure notifications for sending measurement data

In case that the control message is a reply to a `read` message (i.e. has a `relation`), all top-level properties can be set, otherwise only a single top-level element is allowed.

When receiving a `control` message
- the top-level properties `trust` and `notify` overwrite the previous state of those properties entirely
- the elements `limits.power.active.consumption`, `limits.power.active.production`, `failsafes.power.active.consumption`
  and `failsafes.power.active.production` replace the previous state of that element entirely

When receiving a `control` message, that is not a reply to a `read`, the local device SHALL send an [acknowledgement message](@ref ack). A positive
acknowledgement message means that the element contained in the message was valid and has been processed.

The different top-level properties are explained in more detail in the following sections.

### Limits {#ControlLimits}

Power limits are used to regulate the power consumption or production or both of local premises in terms of the EEBUS
use cases LPC and LPP.

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

Limits always have a positive value and a positive duration.
It is not allowed to send a consumption and a production limit in one message.

The local device SHALL reply with a positive acknowledgement message when the limit can be applied, i.e. the
controllable system has accepted it, otherwise it SHALL reply with a negative acknowledgement message with
`"errorNumber": 3` (command execution error). This can happen, for example when the local device has no controllable
system attached or when the controllable system rejects the limit.

The `active` flag can be used to deactivate a previously set limit.

### Failsafes {#ControlFailsafes}

Failsafe limits allow the backend to define a safe state the local device transitions to if EEBUS communication in the
local network is hindered. Semantically, failsafe values are the same as in the EEBUS use cases LPC and LPP. In CLS.EEDI
a failsafe value is expressed in W as an integer. It represents active power.

It is not allowed to send a consumption and a production failsafe in one message.

The local device SHALL reply with an positive acknowledgement message when the failsafe can be applied, i.e. the
controllable system has accepted it, otherwise it SHALL reply with a negative acknowledgement message with
`"errorNumber": 3` (command execution error). This can happen, when the local device has no controllable system attached
or when the controllable system rejects the failsafe value.

In the EEBUS use cases LPC and LPP there is a heartbeat mechanism to monitor connectivity in the home area network and
trigger the failsafe state. Because CLS.EEDI is used for wide area communication there is no heartbeat mechanism.
Consequently, the failsafe state is only related to EEBUS communication in the home area network and not related to CLS
connectivity between the local device and the backend. CLS.EEDI supports setting the failsafe limits only.

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

SHIP trust setup usually happens just once, for example during the initial installation of the local devices.

### Notify

Using this property, the backend can configure notifications of measurement values to be sent by the local device. To
configure these notifications, the following properties need to be specified:

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
sent.

The notifications SHALL be sent as a `state` message with measurement data.

Here is an [example](clseedi/examples/de.keo-connectivity.clseedi.control.notify.json) demonstrating how to configure
notifications.

## Acknowledgement {#ack}

An acknowledgement message SHALL be sent as a reply by the local device to communicate whether the corresponding request
was valid and could be executed or not.

The following message types can cause an acknowledgement message:

- `de.keo-connectivity.clseedi.read`
- `de.keo-connectivity.clseedi.control`

If the `control` message is a reply to a `read` (i.e. has a `relation` filed) it SHALL NOT be acknowledged.

Other message types SHALL NOT cause acknowledgement messages.

The acknowledgement is represented by the `errorNumber` element in the acknowledgement message. A value greater than 0 indicates an error.

The following error numbers are defined:

`errorNumber` | Error type              | Description/Reason
------------- | ----------------------- | ----------------------------------------------------------------------------------------------
0             | Success                 | Success
1             | Schema error            | Invalid message, unable to parse, missing mandatory element
2             | Protocol error          | Unexpected message, e.g. state message with an unknown relation, version mismatch or empty control message
3             | Command execution error | The command could not be executed. There can be many reasons for that error, e.g. limit is rejected by the local device, certificate in trust is invalid or cannot be written, ...
4             | Command not supported   | The command is not supported, e.g. there is no controllable system which supports limitation (see also [supportedUseCases](@ref supportedUseCases))

Take a look at the schema and an example:

* [schema](clseedi/de.keo-connectivity.clseedi.ack.schema.json)
* [example](clseedi/examples/de.keo-connectivity.clseedi.ack.json)

## State {#State}

The data model for `state` messages consists of the following top-level properties:

* `limits` - the current status of the limits for consumption and production
* `failsafes` - the current failsafe values for consumption and production
* `supportedEebusUseCases` - an array of EEBUS use cases the local device supports
* `measurements` - measurement values from potentially different sources
* `notify` - the current configuration of the notifications
* `timestamp` - the timestamp indicating the moment when the message was created

The backend can read the current state of the local device by sending a `read` message (refer to the [Read](@ref Read)
section for details). In the case of a `read` message with empty `parameters`, all properties that are not present in
the reply are expected to be unavailable or unset on the local device. Consequently, a `state` message caused by a
`read` message with empty `parameters` always represents the complete state of the local device and overwrites all
previous `state` messages received from the local device.

The backend can configure which parts of the local device's state it wants to receive, using the `parameters` property.

When receiving a `read` message with non-empty `parameters` ("selective read") the local device SHALL reply with a
`state` message. All top-level properties that are listed in `parameters` for which the local device does not have data,
SHALL NOT be present in the `state` message. All top-level properties that are listed in `parameters` for which the
local device does have data, SHALL be present in the `state` message. All top-level properties that are not listed in
the `parameters` SHALL NOT be present in the `state` message.

When receiving a `state` message that was caused by a `read` message with non-empty `parameters`,  all top-level
properties that are present in the `state` message overwrite all previous state of that top-level property. All
top-level properties that were listed in `parameters` that are not present in the `state` message are expected to not be
available anymore at the local device.

Additionally, a local device can send unsolicited updates of its state. When notifying the state, not all top-level
properties have to be set. This allows the local device to notify only the properties that have changed. When any of the
`limits`, `failsafes`, `supportedEebusUseCases` or `notify` top-level property
are set, they SHALL reflect the complete current state of those top-level properties. When the `measurements` top-level
property is set, every array element SHALL reflect the complete current state of the measurement source represented by
that `id`.

Take a look at the schema and an example:

* [schema](clseedi/de.keo-connectivity.clseedi.state.schema.json)
* [example](clseedi/examples/de.keo-connectivity.clseedi.state.json)


### Limits {#StateLimits}

The `limits` property in the `state` reflects the current power limits in terms of the EEBUS use cases LPC and LPP.
The `active` flag indicates if the power limit has been accepted and is active.
The `duration` indicates the remaining active time in seconds of the power limit.

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

### Measurements {#StateMeasurements}

The measurement values communicated via CLS.EEDI always represent the latest measurements the local device has received from the corresponding measurement
source. If a measurement source disappears, the measurement values of that source SHALL be removed in CLS.EEDI.
Measurement values that are indicated to be invalid (e.g. out of range) by the measurement source SHALL be removed in
CLS.EEDI. However, the technology used to obtain measurements from the measurement source, may not support communicating
invalid values.

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

If other values than the ones defined in this table are encountered, the complete set of metering data for this source
SHALL be ignored.

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
device SHALL periodically send `state` messages with the `measurements` property set.

Here is an [example](clseedi/examples/de.keo-connectivity.clseedi.state.measurements.json) showing the observed state
of the measurement data.

### Supported EEBUS use cases {#supportedUseCases}

The `supportedEebusUseCases` property describes the EEBUS use cases supported by the local device. The presence of an
EEBUS use case in this array indicates that the use case or equivalent functionality is available in the local network.
If the functionality for a use case is no longer available the use case SHALL be removed from the array. A `state`
message including the `supportedEebusUseCases` property SHALL be sent to the backend immediately after the change.

The following table defines which functionality is represented how in the `supportedEebusUseCases` element.

`supportedEebusUseCases` | Definition
--------------------     | -----------------------------------------------------------------------------------------------------
`lpc`                    | Limitation of Power Consumption - a consumption limit and a consumption failsafe map to this use case
`lpp`                    | Limitation of Power Production - a production limit and a production failsafe map to this use case
`mgcp`                   | Monitoring of Grid Connection Point - metering data maps to this use case
`mpc`                    | Monitoring of Power Consumption - metering data maps to this use case

If other values than the ones defined in this table are encountered, the array entry SHALL be ignored.

The following top-level properties of `control` messages can be expected to be handled by local device when the use case is present:
* `lpc` - [limits](@ref ControlLimits) and [failsafes](@ref ControlFailsafes)
* `lpp` - [limits](@ref ControlLimits) and [failsafes](@ref ControlFailsafes)

The following top-level properties of `state` messages can be expected to be set by the local network when the use case is present:
* `lpc` - [limits](@ref StateLimits) and [failsafes](@ref StateFailsafes)
* `lpp` - [limits](@ref StateLimits) and [failsafes](@ref StateFailsafes)
* `mgcp` - [measurements](@ref StateMeasurements)
* `mpc` - [measurements](@ref StateMeasurements)

### Notify

The current configuration of the notifications.

Here is an [example](clseedi/examples/de.keo-connectivity.clseedi.state.notify.json) demonstrating the observed state
of the configured notifications.

## Read {#Read}

Either side of the connection can send a `read` message to the other side. Upon receiving a `read` message,

* the backend sends a `control` message
* the local device sends a `state` message

The backend can configure the specific information it wants to receive from the local device by specifying the desired
top-level [state](@ref State) properties in the `read` message. By selectively choosing the parameters, the backend can
effectively filter the data and retrieve only the relevant information. Alternatively, if the `read` message is sent
with an empty parameter list, it indicates that the backend intends to receive all available information up to the
current moment.

The following list shows the top-level properties from which to retrieve information:
* `limits`
* `failsafes`
* `supportedEebusUseCases`
* `measurements`
* `notify`

The local device cannot configure the information it wants to receive. Instead, upon sending a `read` message, the
backend SHALL send all the information accumulated up to that moment in a `control` message.

Take a look at the schema and examples:

* [schema](clseedi/de.keo-connectivity.clseedi.read.schema.json)
* [example](clseedi/examples/de.keo-connectivity.clseedi.read.json)
* [selective read example](clseedi/examples/de.keo-connectivity.clseedi.read.selective.json)

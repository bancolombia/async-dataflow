---
title: Async DataFlow
---

[![Scorecards supply-chain security](https://github.com/bancolombia/async-dataflow/actions/workflows/scorecards-analysis.yml/badge.svg)](https://github.com/bancolombia/async-dataflow/actions/workflows/scorecards-analysis.yml)

# Async DataFlow

The Async DataFlow component aims to deliver asynchronous responses in real time to client applications, thus enabling end-to-end asynchronois flows without losing the ability to respond in real time or eventually, send data to client applications as a result of asynchronous operations and oriented to `messages / commands / events` on the platform.


## [Channel Sender](/async-dataflow/docs/channel-sender)
Distributed Elixir Cluster implementation of real time with websockets and notifications channels.

```mermaid
    C4Dynamic
    Boundary(aa, "Client side applications") {
        Component(cli, "Single Page Application or Mobile App", "Javascript / Angular /Flutter", "")
    }

    Boundary(xx, "ADF") {
        Component(sender, "Channel Sender", "", "")
    }

    Boundary(zz, "Backend") {
        Component(abl, "Async business logic")
    }

    Rel(cli, sender, "create connection")
    Rel(cli, abl, "Call Http or another entry point definition")
    Rel(abl, cli, "Return Http Empty response")
    Rel(abl, sender, "Send Response (Http)")
    Rel(sender, cli, "Send Response (websocket)")

    UpdateElementStyle(sender, $fontColor="black", $bgColor="orange", $borderColor="black")

    UpdateRelStyle(cli, sender, $offsetX="-40", $offsetY="-20")
    UpdateRelStyle(cli, abl,  $offsetX="-240", $offsetY="-40")
    UpdateRelStyle(abl, cli,  $offsetX="30", $offsetY="-40")
    UpdateRelStyle(abl, sender,  $offsetX="-60", $offsetY="40")
    UpdateRelStyle(sender, cli, $offsetX="-40", $offsetY="20")
    
    UpdateLayoutConfig($c4ShapeInRow="2", $c4BoundaryInRow="2")
```


## [Channel Streams](/async-dataflow/docs/channel-streams)
Distributed Elixir Cluster implementation of a async messages router.

```mermaid
    C4Dynamic

    Boundary(zz, "Backend") {
        Component(abl, "Async business logic")
        SystemDb(bus, "Event bus")
    }
    
    Boundary(xx, "ADF") {
        Component(sender, "Channel Sender", "", "")
        Component(streams, "Channel Streams", "", "")
    }

    Boundary(aa, "Client side applications") {
        Component(cli, "Single Page Application or Mobile App", "Javascript / Angular /Flutter", "")
    }

    Rel(abl, bus, "Emit event")
    Rel(bus, streams, "Subscribe event")
    Rel(streams, sender, "route [Http]")
    Rel(sender, cli, "Push response [websocket]")

    UpdateElementStyle(sender, $fontColor="black", $bgColor="orange", $borderColor="black")
    UpdateElementStyle(streams, $fontColor="black", $bgColor="green", $borderColor="black")

    UpdateRelStyle(abl, bus,  $offsetX="-40", $offsetY="-40")
    UpdateRelStyle(bus, streams, $offsetX="-40", $offsetY="-20")
    UpdateRelStyle(streams, sender, $offsetX="-33", $offsetY="-20")
    UpdateRelStyle(sender, cli, $offsetX="-40", $offsetY="-10")
    
    UpdateLayoutConfig($c4ShapeInRow="2", $c4BoundaryInRow="1")
```

## Clients

### [Client JS](/async-dataflow/docs/client-js)
Javascript library for async data flow implementation for browsers.
### [Client Dart](/async-dataflow/docs/client-dart)
Dart library for async data flow implementation for flutter applications.
### [Elixir Client](/async-dataflow/docs/client-elixir)
Elixir library for async data flow implementation for elixir applications.

## [Examples](/async-dataflow/docs/examples)
The purpose of this project is to help the community to understand more the the async data flow component to implement in full asyncio solutions.

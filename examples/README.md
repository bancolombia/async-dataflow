# Example using Async Data Flow

The purpose of this project is to help the community to understand more the the async data flow component to implement in full asyncio solutions.

## Requirements

- Docker
- Npm
- JVM >= 8

# Execute

First you need to start Docker and create container by [Async Data Flow Sender](https://hub.docker.com/repository/docker/bancolombia/async-dataflow-channel-sender).

```sh
docker run -p 8081:8081 -p 8082:8082 -d --name=asyncdataflow bancolombia/async-dataflow-channel-sender:0.1.0
```

You need to start `back-async-java`, configure your async data flow endpoint in _application.yaml_ this application expose by default port _8080_. you can execute the backend with you favourite IDE or by shell.

```sh
./gradlew bootRun
```

Finally you must install the `front-async-angular` dependencies, configure back-async endpoint and websocket async data flow endpoint in your _environment_ file and execute the solution.

```sh
npm i
npm run start
```

**Great!!!, you will see something like that...**
|Angular|Flutter|
|---|---|
|![imagen](https://user-images.githubusercontent.com/12372370/137996938-10f8e68f-4c85-4ce9-830e-0d01c84458d8.png)|![image](https://user-images.githubusercontent.com/12372370/161621915-d1169c39-9abf-4198-bee0-099fbbce8c78.png)|

You can customize the delay time in the GUI.

## References

- [Async Data Flow - Channel Sender - Repository ](https://github.com/bancolombia/async-dataflow/tree/master/channel-sender)
  - [Docker Hub](https://hub.docker.com/repository/docker/bancolombia/async-dataflow-channel-sender)
  - [Swagger](https://github.com/bancolombia/async-dataflow/tree/master/channel-sender/blob/master/doc/swagger.yaml)
- [Async Data Flow - Channel Client JS - Repository](https://github.com/bancolombia/async-dataflow/clients/clients/client-js)
  - [Npm Package](https://www.npmjs.com/package/chanjs-client)

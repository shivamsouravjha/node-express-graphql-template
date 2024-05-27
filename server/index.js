import express from 'express';
import cors from 'cors';
import { SubscriptionServer } from 'subscriptions-transport-ws/dist/server';
import { GraphQLSchema, execute, subscribe } from 'graphql';
import 'whatwg-fetch';
import dotenv from 'dotenv';
import { ApolloServer } from 'apollo-server-express';
import { createServer } from 'http';
import axios from 'axios';
import { newCircuitBreaker } from '@services/circuitbreaker';
import { corsOptionsDelegate, apolloServerContextResolver } from '@middleware/gqlAuth';
import rTracer from 'cls-rtracer';
import bodyParser from 'body-parser';
import { connect } from '@database';
import { QueryRoot } from '@gql/queries';
import { MutationRoot } from '@gql/mutations';
import { isLocalEnv, isTestEnv, logger } from '@utils/index';
import cluster from 'cluster';
import os from 'os';
import 'source-map-support/register';
import { initQueues } from '@utils/queue';
import { sendMessage } from '@services/slack';
import { SubscriptionRoot } from '@gql/subscriptions';
import depthLimit from 'graphql-depth-limit';
import logReqRes from './middleware/logger';
const totalCPUs = os.cpus().length;
let app, httpServer;
const connections = new Set();
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

export const fetchFromGithub = async query =>
  axios.get(`https://api.github.com/search/repositories?q=${query}&per_page=2`);
const githubBreaker = newCircuitBreaker(fetchFromGithub, 'Github API is down');
export const init = async () => {
  // configure environment variables
  dotenv.config({
    path: `.env.${process.env.ENVIRONMENT_NAME}`
  });
  // connect to database
  connect();

  // create the graphQL schema
  const schema = new GraphQLSchema({
    query: QueryRoot,
    mutation: MutationRoot,
    subscription: SubscriptionRoot
  });
  if (!app) {
    app = express();
  }
  app.use(express.json());
  app.use(rTracer.expressMiddleware());
  app.use(cors(corsOptionsDelegate));
  app.use(logReqRes);
  app.use(bodyParser.json());
  app.use(bodyParser.urlencoded({ extended: true }));
  app.get('/github', async (req, res) => {
    const response = await githubBreaker.fire(req.query.repo);
    if (response.data) {
      return res.json({ data: response.data });
    } else {
      return res.status(424).json({ error: response });
    }
  });
  app.get('/', (req, res) => {
    const message = 'Service up and running!';
    sendMessage(message);
    logger().info(message);
    res.json({ data: message });
  });
  if (!isTestEnv()) {
    httpServer = createServer(app);
    const server = new ApolloServer({
      schema,
      introspection: isLocalEnv(),
      validationRules: [depthLimit(6)],
      context: apolloServerContextResolver,
      formatError: e => {
        logger().info({ e });
        return e.message;
      }
    });
    await server.start();
    server.applyMiddleware({ app });
    const subscriptionServer = SubscriptionServer.create(
      { schema, execute, subscribe },
      { server: httpServer, path: server.graphqlPath }
    );
    ['SIGINT', 'SIGTERM'].forEach(signal => {
      process.on(signal, () => subscriptionServer.close());
    });
    httpServer.on('connection', conn => {
      connections.add(conn);
      conn.on('close', () => {
        console.log('closed http server');
        connections.delete(conn);
      });
    });

    httpServer.listen(9000, () => {
      console.log(`Server is now running on http://localhost:9000/graphql`);
    });
    initQueues();
  }
};
logger().info({ ENV: process.env.NODE_ENV });
let shuttingDown = false;
const gracefulShutdown = signal => {
  console.log(`${signal} received, initiating shutdown...`);
  shuttingDown = true; // Flag to prevent new workers from being forked
  if (cluster.isMaster) {
    const shutdownPromises = [];
    for (const id in cluster.workers) {
      const worker = cluster.workers[id];
      // Setup listeners before sending the kill signal
      const shutdownPromise = new Promise(resolve => {
        worker.on('exit', () => {
          console.log(`Worker ${worker.id} has shut down.`);
          resolve();
        });
        worker.on('error', err => {
          console.error(`Error shutting down worker ${worker.id}:`, err);
          resolve(); // Resolve anyway to avoid hanging shutdown
        });
        worker.kill(signal); // Now send the shutdown signal
      });
      shutdownPromises.push(shutdownPromise);
    }
    Promise.all(shutdownPromises).then(async () => {
      console.log('All workers have been terminated, shutting down master.');
      await sleep(5000); // Sleep for 19 seconds
      process.exit(0);
    });
    // Optional: set a timeout to force shutdown if workers take too long
    setTimeout(() => {
      console.log('Forcefully shutting down master after timeout.');
      process.exit(1);
    }, 10000); // Adjust timeout as needed
  } else {
    // Worker cleanup logic here, then exit
    console.log(`Worker process ${process.pid} exiting.`);
    process.exit(1);
  }
};
process.on('SIGTERM', gracefulShutdown);
process.on('SIGINT', gracefulShutdown);

if (!isTestEnv() && !isLocalEnv() && cluster.isMaster) {
  console.log(`Number of CPUs is ${totalCPUs}`);
  console.log(`Master ${process.pid} is running`);
  // Fork workers.
  console.log(totalCPUs, 'totalCPUs');
  for (let i = 0; i < totalCPUs; i++) {
    const worker = cluster.fork();
    worker.on('exit', (code, signal) => {
      console.log(`Worker ${worker.process.pid} died with code ${code} and signal ${signal}`);
      if (!shuttingDown) {
        console.log("Let's fork another worker!");
        cluster.fork();
      }
    });
  }
} else {
  console.log('Worker process started, initializing...');
  init();
}
export { app };

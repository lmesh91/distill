import { MongoClient, ServerApiVersion } from 'mongodb';

const uri = process.env.MONGODB_URI;
const databaseName = process.env.MONGODB_DB ?? 'distill';

if (!uri) {
  throw new Error('MONGODB_URI is not set');
}

export const mongoClient = new MongoClient(uri, {
  serverApi: {
    version: ServerApiVersion.v1,
    strict: true,
    deprecationErrors: true
  }
});

export const db = mongoClient.db(databaseName);

export async function connectDatabase() {
  await mongoClient.connect();

  await db.command({
    ping: 1
  });

  console.log('Connected to MongoDB');
}
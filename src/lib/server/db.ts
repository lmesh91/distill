import { env } from '$env/dynamic/private';
import { MongoClient, ServerApiVersion } from 'mongodb';
import { ensureIndexes } from './indexes';

let mongoClient: MongoClient | undefined;
let connection: Promise<MongoClient> | undefined;

function getMongoClient() {
	if (!env.MONGODB_URI) {
		throw new Error('MONGODB_URI is not set');
	}

	mongoClient ??= new MongoClient(env.MONGODB_URI, {
		serverApi: {
			version: ServerApiVersion.v1,
			strict: true,
			deprecationErrors: true
		}
	});

	return mongoClient;
}

export function getDatabase() {
	return getMongoClient().db(env.MONGODB_DB ?? 'distill');
}

export async function connectDatabase() {
	const client = getMongoClient();

	connection ??= client
		.connect()
		.then(async () => {
			await getDatabase().command({ ping: 1 });
			await ensureIndexes();
			return client;
		})
		.catch((error: unknown) => {
			connection = undefined;
			throw error;
		});

	return connection;
}

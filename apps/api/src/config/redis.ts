import { createClient } from 'redis';
import { env } from './env';

const redisClient = createClient({
  url: env.redis.url,
});

redisClient.on('error', (err) => console.error('❌ Redis Error:', err));
redisClient.on('connect', () => console.log('✅ Redis conectado'));

export async function initRedis() {
  await redisClient.connect();
}

export async function setCache(key: string, value: any, ttl = 3600) {
  await redisClient.setEx(key, ttl, JSON.stringify(value));
}

export async function getCache(key: string) {
  const data = await redisClient.get(key);
  return data ? JSON.parse(data) : null;
}

export async function delCache(key: string) {
  await redisClient.del(key);
}

export async function clearCachePattern(pattern: string) {
  const keys = await redisClient.keys(pattern);
  if (keys.length > 0) await redisClient.del(keys);
}

export default redisClient;

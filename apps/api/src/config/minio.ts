import * as Minio from 'minio';
import { env } from './env';

const minioClient = new Minio.Client({
  endPoint: env.minio.endpoint,
  port: env.minio.port,
  useSSL: env.minio.useSSL,
  accessKey: env.minio.accessKey,
  secretKey: env.minio.secretKey,
});

const BUCKET = env.minio.bucket;

export async function initMinio() {
  try {
    const exists = await minioClient.bucketExists(BUCKET);
    if (!exists) {
      await minioClient.makeBucket(BUCKET, 'us-east-1');
      console.log(`✅ Bucket '${BUCKET}' criado com sucesso`);
      // Set bucket policy to allow downloads
      const policy = {
        Version: '2012-10-17',
        Statement: [{
          Effect: 'Allow',
          Principal: { AWS: ['*'] },
          Action: ['s3:GetObject'],
          Resource: [`arn:aws:s3:::${BUCKET}/*`],
        }],
      };
      await minioClient.setBucketPolicy(BUCKET, JSON.stringify(policy));
    }
    console.log(`✅ MinIO conectado - Bucket: ${BUCKET}`);
  } catch (error) {
    console.error('❌ Erro ao conectar MinIO:', error);
  }
}

export async function uploadFile(key: string, buffer: Buffer, contentType: string, metadata?: Record<string, string>): Promise<string> {
  await minioClient.putObject(BUCKET, key, buffer, buffer.length, {
    'Content-Type': contentType,
    ...metadata,
  });
  return key;
}

export async function getFileUrl(key: string, _expiry = 86400): Promise<string> {
  return `${env.urls.api}/api/files/${key}`;
}

export async function getFileBuffer(key: string): Promise<Buffer> {
  const stream = await minioClient.getObject(BUCKET, key);
  const chunks: Buffer[] = [];
  return new Promise((resolve, reject) => {
    stream.on('data', (chunk: Buffer) => chunks.push(chunk));
    stream.on('end', () => resolve(Buffer.concat(chunks)));
    stream.on('error', reject);
  });
}

export async function deleteFile(key: string): Promise<void> {
  await minioClient.removeObject(BUCKET, key);
}

export async function listFiles(prefix: string): Promise<Minio.BucketItem[]> {
  const items: Minio.BucketItem[] = [];
  const stream = minioClient.listObjects(BUCKET, prefix, true);
  return new Promise((resolve, reject) => {
    stream.on('data', (item: Minio.BucketItem) => items.push(item));
    stream.on('end', () => resolve(items));
    stream.on('error', reject);
  });
}

export { minioClient, BUCKET };
export default minioClient;
